  
  def time_check_log(label)
    tstart = Time.now
	  result = yield
	  tstop = Time.now
	  rpt = "TIMECHECK #{label}: "+(tstop-tstart).to_s+" sec."
    logger.debug rpt
    result
  end
    