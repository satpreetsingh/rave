# Scripts to handle settings

opt <- list(
  # Max memory in GB. R cannot auto detect RAM cap in linux and macos so I set this value
  max_mem = 256,

  # hard drive speed: seconds per MB (sec/MB)
  drive_speed = c(0.02, 0.05),

  # disable startup disk check (speed test)
  disable_startup_speed_check = FALSE,

  # check threejsr, rutabaga updates
  check_updates_onstartup = T,

  # data repositories
  raw_data_dir = '~/rave_data/raw_dir/',
  data_dir = '~/rave_data/data_dir/',
  module_root_dir = '~/rave_modules/',
  module_lookup_file = '~/rave_modules/modules.csv',

  # Enable logger
  logger_enabled = TRUE,
  logger_level = 'DEBUG',

  # color logger
  crayon_enabled = TRUE,


  # init app test_mode
  test_mode = FALSE,

  # Not really used, might be depricated in the future. currently used to trim environment
  # and remove big objects
  big_object_size = 500000,

  # Not used, but maybe useful in the future
  server_time_zone = 'America/Chicago',


  # input update firing speed (20ms default)
  delay_input = 20,

  # number of cores to be used
  max_worker = 8L,

  ## SUMA

  suma_to_niml = '~/abin/ConvertDset -o_niml -input %s -i_1D -node_index_1D %s -prefix %s',
  suma_send_niml = '~/abin/DriveSuma -com surf_cont -load_dset %s',  # Not used because x11 on mac sucks
  suma_nodes_per_electrodes = 42L,
  suma_parallel_cores = 2L,
  # dyld_library_path = '/opt/X11/lib/flat_namespace',
  suma_lib = c('DYLD_LIBRARY_PATH=/opt/X11/lib/flat_namespace', "DYLD_FALLBACK_LIBRARY_PATH=/Applications/AFNI"),
  suma_path = '/Applications/AFNI',
  suma_spec_file = 'test.spec',

  matlab_path = '/Applications/MATLAB_R2016b.app/bin',
  py2_path = Sys.which('python'),
  py3_path = Sys.which('python'),
  py_virtualenv = '',

  # images
  image_width = 1280L,
  image_height = 768L,

  # Cache
  # Use fst package to cache power phase volt after wavelet and reference?
  # If running in the local machine, we don't need it because h5 is fast enough
  # and h5 with mpi is even faster
  # However, if data is stored at data server, fst is way faster than h5 (single threaded with forked)
  # Also on windows, fst should be faster than hdf5 in general
  fast_cache = TRUE,






  # Deprecated
  debug = FALSE,
  session_based_datarepo = FALSE,
  module_export = './export',
  content_regex = 'e([0-9]+)[^0-9]*',
  content_format = 'mat',
  export_path = './export',
  temp_dir = 'temp',
  suma_monitor_dir = 'temp/monitor',
  suma_export_dir = 'suma',  # [SUBJECT]/suma, must be relative path, dirname, stores spec files
  suma_gifti_name_regex = 'electrode_[a-zA-Z0-9]+.gii'
)

# TODO We can use this to make sure we are attaching the dataset to the correct surface, asuming we know / can set the surface name of the electrodes
# -load_dset DSET: Load a dataset
# ! NOTE: When using -load_dset you can follow it
# with -surf_label in order to attach
# the dataset to a particular target surface.

#' Internal R6 class for rave-options
#' @import yaml
#' @import utils
Options <- R6::R6Class(
  "Options",
  private = list(
    opts = list()
  ),
  public = list(
    initialize = function(conf_path = '~/.rave.yaml', save_default = F){

      private$opts = opt
      if(length(conf_path) != 1 || is.na(conf_path) || !is.character(conf_path) || !file.exists(conf_path)){
        private$opts = opt
        if(save_default){
          self$save_settings(path = '~/.rave.yaml')
        }
      }else{
        self$load_settings(conf_path = conf_path)
      }
    },
    get_options = function(...){
      re <- private$opts[...]
      if(length(re) == 1){
        re = unlist(re)
      }
      return(re)
    },
    set_options = function(...){
      o = list(...)
      for(n in names(o)){
        private$opts[[n]] = o[[n]]
      }
      return(invisible(self$get_options(names(o))))
    },
    reset = function(){
      private$opts = opt
    },
    load_settings = function(
      conf_path = system.file('settings.yaml', package = 'rave')
    ){
      if(length(conf_path) != 1 || is.na(conf_path) || !is.character(conf_path) || !file.exists(conf_path)){
        return()
      }
      v = yaml::read_yaml(conf_path)

      do.call(self$set_options, args = v)
      self$set_options(conf_path = conf_path)
    },
    save_settings = function(path = '~/.rave.yaml'){
      if(!file.exists(path)){
        dname = dirname(path)
        if(!file.exists(dname)){
          dir.create(dname)
        }
        mw = self$get_options('max_worker')
        if(length(mw) > 0 && mw == 3L && 'parallel' %in% installed.packages()[,1]){
          self$set_options(max_worker = future::availableCores() - 1)
        }
      }
      opt = private$opts
      yaml::write_yaml(opt, file = path, fileEncoding = 'UTF-8')
    }
  )
)

# export
# rave_opts <- Options$new(conf_path = '~/.rave.yaml', save_default = T)

#' Function to locally save options (deprecated)
#' @export
save_options <- function(){
  ..setup_env$rave_opts$save_settings()
}

#' Function to change rave-options
#' @param ... Key-Value option pairs
#' @param save save to disk? ignored most of the time
#' @param launch_gui launch shiny app?
#' @export
rave_options <- function(..., .save = T, launch_gui = T){
  if(!exists('rave_opts', envir = ..setup_env, inherits = F)){
    ..setup_env$rave_opts <- Options$new(conf_path = '~/.rave.yaml', save_default = T)
  }
  args = list(...)
  if(length(args) && length(names(args))){
    # set options
    re = ..setup_env$rave_opts$set_options(...)

    if(.save){
      ..setup_env$rave_opts$save_settings()
    }
  }else{
    # get options
    re = ..setup_env$rave_opts$get_options(...)
    if(length(args) == 0 && launch_gui){
      # make a small shiny app to set options
      return(rave_options_gui())
    }
  }

  return(re)
}







#' Default setup for rave, mainly create forked sub-processes
#' @param func NULL by default, function to be added to default (dangerous)
#' @export
rave_setup <- function(func = NULL){
  if(!is.function(func)){
    if(length(..setup_env$setup_func) == 0){
      n_workers = max(rave_options('max_worker'), 1)
      # if(stringr::str_detect(stringr::str_to_lower(Sys.info()['sysname']), 'win[3d]')){
      #   mcl = parallel::makeCluster
      # }else{
      #   mcl = parallel::makeForkCluster
      # }


      # if(is(..setup_env$workers, 'cluster')){
      #   parallel::stopCluster(..setup_env$workers)
      # }
      # ..setup_env$workers = mcl(n_workers)

      # future::plan(future::cluster, workers = ..setup_env$workers)

      future::plan(future::multiprocess, workers = n_workers)

      # check crayon
      if(rave::rave_options('crayon_enabled')){
        if(exists('RStudio.Version') && is.function(RStudio.Version)){
          rsver = as.character(RStudio.Version()$version)
          if(utils::compareVersion('1.1', rsver)  > 0){
            warning("Please install newest version of RStudio")
            rave::rave_options(crayon_enabled = FALSE, .save = F)
          }
        }else{
          rave::rave_options(crayon_enabled = FALSE, .save = F)
        }
      }
    }
  }else{
    ..setup_env$setup_func[[length(..setup_env$setup_func) + 1]] = func
  }
  if(length(..setup_env$setup_func)){
    lapply(..setup_env$setup_func, function(f){
      if(is.function(f)){
        f()
      }
    })
  }
}






