undef("dtrend_leftdim")
function dtrend_leftdim(x:numeric, opt[1]:logical)
;
; utility routine ... makes for cleaner code
;
; Pre V5.2.0: Reorder so time is rightmost; detrend the time series,
;     reorder back
;
; Post V5.2.0: Updated 11/1/09 to use dtrend_n.
;
local x_dtrend
begin
  x_dtrend = x                             ; retain meta data
  ; x_dtrend = (/dtrend_n( x, opt, 0) /)
  ; printVarSummary(x)
  x_dtrend = dtrend_n( x, opt, 0)
  return (x_dtrend)
end

undef("process")
function process (type,opt)
local method,dim_to_mean,type_clim,dim,dim_to_mean_clim,tem,clim,anom,id,output,var,trend
begin
  ; if(typeof(opt) .eq. "string")
  ;   method = opt
  ; else
  ;   method = get_res_value_keep(opt,"method","anom")
  ; end if
  method = where(typeof(opt) .eq. "string",opt,get_res_value_keep(opt,"method","anom"))
  dim_to_mean = "month"
  ; dim_to_mean = get_res_value_keep(opt,"dim_to_mean","month")
  if(isatt(opt,"add_dim_to_mean"))
    dim_to_mean := append(dim_to_mean,opt@add_dim_to_mean)
    ; print(dim_to_mean)
  end if
  if(dimsizes(type@year) .eq. 1) 
    if(method .eq. "anom")
      if(isatt(opt,"clim"))
        type_clim = type
        dim_to_mean_clim := append(dim_to_mean,"year")
          type_clim@year := opt@clim
        ; printVarSummary(type)
        tem = readReanalysis(type_clim,method)
        ; printVarSummary(tem)
        ; print(type@year)
        ; anom = tem({type@year},:,:)
        ; tem = read_from_config(type_clim,opt)
        ; printVarSummary(type)
        clim = dim_avg_n_Wrap(tem, dim_to_mean_clim)
        tem := readReanalysis(type,opt)
        tem := dim_avg_n_Wrap(tem, dim_to_mean)
        anom := tem-clim
        copy_VarCoords(clim, anom)
        return(anom)
      else
        printc("you need to define period for climatology","red")
      end if
    else
      method = "None"
    end if 
  end if
  ; print(method)

  call_process = "process"
  ListAppend(call_stream, call_process)


  id = type
    id@type = type
    id@method = method
    id@dim_to_mean = str_concat(dim_to_mean)
    id@call = call_process
    id@detrend = get_res_value_keep(opt,"detrend",False)
  if(method .eq. "trend")
    trend_scale = get_res_value_keep(opt,"trend_scale",1.)
    id@trend_scale = trend_scale
  end if
  ; print(getBufferId(id))
  if(call_stream[0] .eq. call_process .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
      printc("read buffer: "+call_process,"blue")
      return(read_buffer(id))
  end if
  output = (/"data: "+type@source,"method: "+method/)
  printc(output,"purple")
  if(str_upper(type) .eq. "WINDSPEED")
    tu = type
    tu = "u"
    u = read_from_config(tu,opt)
    tv = type
    tv = "v"
    v = read_from_config(tv,opt)
    var = wind_speed(u, v)
  elseif(str_upper(type) .eq. "WINDSPEED_SURFACE")
    tu = type
    tu = "u10m"
    u = read_from_config(tu,opt)
    tv = type
    tv = "v10m"
    v = read_from_config(tv,opt)
    var = wind_speed(u, v)
  elseif(is_element(type,(/"CE","drought","tn90p","tn95p","tx90p","tx95p","chw","tx90pInt","net90p","net90pInt","net85p","net85pInt","net80p","net80pInt","net75p","net75pInt","precip90p","precip90pInt","precip85p","precip85pInt","precip80p","precip80pInt","precip75p","precip75pInt","spei90p","spei90pInt","spei85p","spei85pInt","spei80p","spei80pInt","spei75p","spei75pInt","spei10p","spei10pInt","spei15p","spei15pInt","spei20p","spei20pInt","spei25p","spei25pInt","spei30p","spei30pInt","spei35p","spei35pInt"/)))
    var = read_JA_HW(type,opt)
  else
    var = readReanalysis(type,opt)

    ; var = read_from_config(type,opt)
  end if
  ; printMinMax(var,False)
  if(is_element(str_upper(type),(/"H","HGT"/)) .and. str_upper(type@source) .eq. "ERA5")
    tem = var/9.8
    copy_VarCoords(var, tem)
    copy_VarAtts(var, tem)
    var := tem
  end if

  dim      = dimsizes(var)
  ;methods = (/"clim","anom","std"/)
  ; if(isatt(opt,"add_dim_to_mean"))
  ;   dim_to_mean := append(dim_to_mean,opt@add_dim_to_mean)
  ; end if
  ; print("method: "+method)
  var_name = var@name
  ; printVarSummary(type)
  isVarMonth = isdim(var, "month")
  if(method .eq. "none")
    return var
  end if
  if(method .eq. "mean")
    ; if(dimsizes(type@year) .eq. 1)
    ;   tem = dim_avg_n_Wrap(var,dim_to_mean)
    ;   return(tem(0))
    var := dim_avg_n_Wrap(var,dim_to_mean)
    ; if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
    ;   write_buffer(tem,id)
    ; end if
    ; return(tem)
  end if

  if(method .eq. "sum")
    ; if(dimsizes(type@year) .eq. 1)
    ;   tem = dim_avg_n_Wrap(var,dim_to_mean)
    ;   return(tem(0))
    tem = dim_sum_n_Wrap(var, dim_to_mean)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(tem,id)
    end if
    return(tem)
    ; return(dim_avg_n_Wrap(var,dim_to_mean))
  end if

  if(method .eq. "clim")
    dim_to_mean := append(dim_to_mean,"year") 
    ; dim_to_mean := get_res_value_keep(opt,"dim_to_mean",(/"year","month"/))
    tem := dim_avg_n_Wrap(var,dim_to_mean)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(tem,id)
    end if
    return(tem)
  end if

  if(method .eq. "trend")
    var := dim_avg_n_Wrap(var, dim_to_mean)
    trend = regCoef_n(type@year,var,0,0)
    trend = (/trend*trend_scale/)
    copy_VarCoords_not_n(var,trend,0)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(trend,id)
    end if
    return(trend)
  end if

  ;去趋势
  if(get_res_value_keep(opt,"detrend",False) .and. method .ne. "None")
    ; var = dtrend_msg_n(var&year, var, True, True, 0)
    var = (/dtrend_leftdim((/var/), True)/)
    if(isatt(type, "polyLon") .and. isatt(type, "polyLat"))then
      var = extract(var,type@polyLon,type@polyLat)
    end if
    print("detrend")
  end if
  ; print("123")
  if(type .eq. "spei")then
    ; print("should process")
    ; printMinMax(var, 1)
    var = (/where(var .ge. 1e10 .or. var .le. -1e10, var@_FillValue, var)/)
    ; printMinMax(var, 1)
  end if
  if(method .eq. "stddev")
    var := dim_avg_n_Wrap(var, dim_to_mean)
    if(isatt(opt, "designal"))then
      print("designal")
      var = (/designal(var,opt@designal)/)
    end if
    sd = dim_stddev_n_Wrap(var,0)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      ; print(id)
      write_buffer(sd,id)
    end if
    return(sd)
  end if


  ; if(.not. isVarMonth);处理气候态和去趋势部分
  ;   var_c      = dim_avg_n_Wrap(var,0)
  ;   if(opt@method .eq. "clim") return(var_c) end if
  ; else
  ;   if(opt@method .eq. "clim")  
  ;     return(dim_avg_n_Wrap(var, (/0,1/)))
  ;   end if
  ; end if


  if(method .eq. "anom") 
    dim_to_anom = get_res_value_keep(opt,"dim_to_anom","year")  
    var := dim_rmvmean_n_Wrap(var, dim_to_anom) 
  end if
  
  if(method .eq. "std") 
    var := dim_standardize_n_Wrap(var,0, 0) 
    print("std")
  end if

  if(method .eq. "meridionalGradient")then
    cyclic = get_res_value_keep(method, "cyclic", False)
    tem := grad_latlon_cfd(var, var&lat, var&lon, cyclic, False)
    var := tem[0]
  end if

  if(method .eq. "zonalGradient")then
    cyclic = get_res_value_keep(method, "cyclic", False)
    tem := grad_latlon_cfd(var, var&lat, var&lon, cyclic, False)
    var := tem[1]
  end if

  var := dim_avg_n_Wrap(var,dim_to_mean)

  if(isatt(method, "designal"))then
    var = (/designal(var,method@designal)/)
  end if
  ; if(isVarMonth) var := dim_avg_n_Wrap(var, "month") end if
  ; var0!0 = "year"
  ; var0&year := type@year
  ; var0@name = var_name
    ; print(var0@mon_name)
  if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(var,id)
  end if
  return(var)
end

undef("process_CMIP6")
function process_CMIP6 (type,opt)
local method,dim_to_mean,type_clim,dim,dim_to_mean_clim,tem,clim,anom,id,output,var
begin

  ; if(typeof(opt) .eq. "string")
  ;   method = opt
  ; else
  ;   method = get_res_value_keep(opt,"method","anom")
  ; end if

  method = where(typeof(opt) .eq. "string",opt,get_res_value_keep(opt,"method","anom"))
  dim_to_mean = "month"
  ; dim_to_mean = get_res_value_keep(opt,"dim_to_mean","month")
  if(isatt(opt,"add_dim_to_mean"))
    dim_to_mean := append(dim_to_mean,opt@add_dim_to_mean)
    ; print(dim_to_mean)
  end if
  if(dimsizes(type@year) .eq. 1) 
    if(method .eq. "anom")
      if(isatt(opt,"clim"))
        type_clim = type
        dim_to_mean_clim := append(dim_to_mean,"year")
          type_clim@year := opt@clim
        ; printVarSummary(type)
        tem = readCMIP6(type_clim,opt)
        clim = dim_avg_n_Wrap(tem, dim_to_mean_clim)
        tem := readCMIP6(type,opt)
        tem := dim_avg_n_Wrap(tem, dim_to_mean)
        anom = tem -clim
        copy_VarCoords(clim, anom)
        return(anom)
      else
        printc("you need to define period for climatology","red")
      end if
    else
      method = "None"
    end if 
  end if
  ; print(method)
  call_process = "process"
  ListAppend(call_stream, call_process)


  id = type
    id@type = type
    id@method = method
    id@dim_to_mean = str_concat(dim_to_mean)
    id@call = call_process
    id@detrend = get_res_value_keep(opt,"detrend",False)
  if(method .eq. "trend")
    trend_scale = get_res_value_keep(opt,"trend_scale",1.)
    id@trend_scale = trend_scale
  end if
  if(call_stream[0] .eq. call_process .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
      printc("read buffer: "+call_process,"blue")
      return(read_buffer(id))
  end if
  output = (/"Source: "+type@source,"Method: "+method,"Model: "+type@model/)
  printc(output,"purple")
  var = readCMIP6(type,True)
  ; printMinMax(var,False)
  if(is_element(str_upper(type),(/"H","HGT"/)) .and. str_upper(type@source) .eq. "ERA5")
    tem = var/9.8
    copy_VarCoords(var, tem)
    copy_VarAtts(var, tem)
    var := tem
  end if
  dim      = dimsizes(var)
  ;methods = (/"clim","anom","std"/)
  ; if(isatt(opt,"add_dim_to_mean"))
  ;   dim_to_mean := append(dim_to_mean,opt@add_dim_to_mean)
  ; end if
  ; print("method: "+method)
  var_name = var@name
  ; printVarSummary(type)
  isVarMonth = isdim(var, "month")

  if(method .eq. "mean")
    ; if(dimsizes(type@year) .eq. 1)
    ;   tem = dim_avg_n_Wrap(var,dim_to_mean)
    ;   return(tem(0))
    var := dim_avg_n_Wrap(var,dim_to_mean)
    ; if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
    ;   write_buffer(tem,id)
    ; end if
    ; return(tem)
  end if

  if(method .eq. "sum")
    ; if(dimsizes(type@year) .eq. 1)
    ;   tem = dim_avg_n_Wrap(var,dim_to_mean)
    ;   return(tem(0))
    tem = dim_sum_n_Wrap(var, dim_to_mean)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(tem,id)
    end if
    return(tem)
    ; return(dim_avg_n_Wrap(var,dim_to_mean))
  end if

  if(method .eq. "clim")
    dim_to_mean := append(dim_to_mean,"year") 
    ; dim_to_mean := get_res_value_keep(opt,"dim_to_mean",(/"year","month"/))
    print("reading complete")
    tem := dim_avg_n_Wrap(var,dim_to_mean)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(tem,id)
    end if
    return(tem)
  end if

  if(method .eq. "trend")
    var := dim_avg_n_Wrap(var, dim_to_mean)
    trend = regCoef_n(type@year,var,0,0)
    trend = (/trend*trend_scale/)
    copy_VarCoords_not_n(var,trend,0)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(trend,id)
    end if
    return(trend)
  end if

  ;去趋势
  if(get_res_value_keep(opt,"detrend",False) .and. method .ne. "None") 
    var = (/dtrend_leftdim((/var/), True)/)
    print("detrend")
  end if

  if(method .eq. "stddev")
    var := dim_avg_n_Wrap(var, dim_to_mean)
    sd = dim_stddev_n_Wrap(var,0)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      ; print(id)
      write_buffer(sd,id)
    end if
    return(sd)
  end if



  ; if(.not. isVarMonth);处理气候态和去趋势部分
  ;   var_c      = dim_avg_n_Wrap(var,0)
  ;   if(opt@method .eq. "clim") return(var_c) end if
  ; else
  ;   if(opt@method .eq. "clim")  
  ;     return(dim_avg_n_Wrap(var, (/0,1/)))
  ;   end if
  ; end if


  if(method .eq. "anom") 
    dim_to_anom = get_res_value_keep(opt,"dim_to_anom","year")
    var := dim_rmvmean_n_Wrap(var, dim_to_anom) 
  end if

  if(method .eq. "std") 
    var := dim_standardize_n_Wrap(var,0, 0) 
  end if

  var := dim_avg_n_Wrap(var,dim_to_mean)
  ; if(isVarMonth) var := dim_avg_n_Wrap(var, "month") end if
  
  ; var0!0 = "year"
  ; var0&year := type@year
  ; var0@name = var_name
    ; print(var0@mon_name)
  if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(var,id)
  end if
  return(var)
end

undef("process_CESM2LE")
function process_CESM2LE (type,opt)
local method,dim_to_mean,type_clim,dim,dim_to_mean_clim,tem,clim,anom,id,output,var
begin
; if(typeof(opt) .eq. "string")
  ;   method = opt
  ; else
  ;   method = get_res_value_keep(opt,"method","anom")
  ; end if

  method = where(typeof(opt) .eq. "string",opt,get_res_value_keep(opt,"method","anom"))
  dim_to_mean = "month"
  ; dim_to_mean = get_res_value_keep(opt,"dim_to_mean","month")
  if(isatt(opt,"add_dim_to_mean"))
    dim_to_mean := append(dim_to_mean,opt@add_dim_to_mean)
    ; print(dim_to_mean)
  end if
  if(dimsizes(type@year) .eq. 1) 
    if(method .eq. "anom")
      if(isatt(opt,"clim"))
        type_clim = type
        dim_to_mean_clim := append(dim_to_mean,"year")
          type_clim@year := opt@clim
        ; printVarSummary(type)
        tem = readCESM2LE(type_clim,opt)
        clim = dim_avg_n_Wrap(tem, dim_to_mean_clim)
        tem := readCESM2LE(type,opt)
        tem := dim_avg_n_Wrap(tem, dim_to_mean)
        anom = tem -clim
        copy_VarCoords(clim, anom)
        return(anom)
      else
        printc("you need to define period for climatology","red")
      end if
    else
      method = "None"
    end if 
  end if
  ; print(method)
  call_process = "process"
  ListAppend(call_stream, call_process)


  id = type
    id@type = type
    id@method = method
    id@dim_to_mean = str_concat(dim_to_mean)
    id@call = call_process
    id@detrend = get_res_value_keep(opt,"detrend",False)
  if(method .eq. "trend")
    trend_scale = get_res_value_keep(opt,"trend_scale",1.)
    id@trend_scale = trend_scale
  end if
  if(call_stream[0] .eq. call_process .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
      printc("read buffer: "+call_process,"blue")
      return(read_buffer(id))
  end if
  output = (/"Source: "+type@source,"Method: "+method,"Member: "+type@member/)
  printc(output,"purple")
  var = readCESM2LE(type,True)
  ; printVarSummary(var)
  ; printMinMax(var,False)
  if(is_element(str_upper(type),(/"H","HGT"/)) .and. str_upper(type@source) .eq. "ERA5")
    tem = var/9.8
    copy_VarCoords(var, tem)
    copy_VarAtts(var, tem)
    var := tem
  end if
  dim      = dimsizes(var)
  ;methods = (/"clim","anom","std"/)
  ; if(isatt(opt,"add_dim_to_mean"))
  ;   dim_to_mean := append(dim_to_mean,opt@add_dim_to_mean)
  ; end if
  ; print("method: "+method)
  var_name = var@name
  ; printVarSummary(type)
  isVarMonth = isdim(var, "month")

  if(method .eq. "mean")
    ; if(dimsizes(type@year) .eq. 1)
    ;   tem = dim_avg_n_Wrap(var,dim_to_mean)
    ;   return(tem(0))
    var := dim_avg_n_Wrap(var,dim_to_mean)
    ; if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
    ;   write_buffer(tem,id)
    ; end if
    ; return(tem)
  end if

  if(method .eq. "sum")
    ; if(dimsizes(type@year) .eq. 1)
    ;   tem = dim_avg_n_Wrap(var,dim_to_mean)
    ;   return(tem(0))
    tem = dim_sum_n_Wrap(var, dim_to_mean)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(tem,id)
    end if
    return(tem)
    ; return(dim_avg_n_Wrap(var,dim_to_mean))
  end if

  if(method .eq. "clim")
    dim_to_mean := append(dim_to_mean,"year") 
    ; dim_to_mean := get_res_value_keep(opt,"dim_to_mean",(/"year","month"/))
    print("reading complete")
    tem := dim_avg_n_Wrap(var,dim_to_mean)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(tem,id)
    end if
    return(tem)
  end if

  if(method .eq. "trend")
    var := dim_avg_n_Wrap(var, dim_to_mean)
    trend = regCoef_n(type@year,var,0,0)
    trend = (/trend*trend_scale/)
    copy_VarCoords_not_n(var,trend,0)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(trend,id)
    end if
    return(trend)
  end if

  ;去趋势
  if(get_res_value_keep(opt,"detrend",False) .and. method .ne. "None") 
    var = (/dtrend_leftdim((/var/), True)/)
    print("detrend")
  end if

  if(method .eq. "stddev")
    var := dim_avg_n_Wrap(var, dim_to_mean)
    sd = dim_stddev_n_Wrap(var,0)
    if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
      ; print(id)
      write_buffer(sd,id)
    end if
    return(sd)
  end if



  ; if(.not. isVarMonth);处理气候态和去趋势部分
  ;   var_c      = dim_avg_n_Wrap(var,0)
  ;   if(opt@method .eq. "clim") return(var_c) end if
  ; else
  ;   if(opt@method .eq. "clim")  
  ;     return(dim_avg_n_Wrap(var, (/0,1/)))
  ;   end if
  ; end if


  if(method .eq. "anom") 
    dim_to_anom = get_res_value_keep(opt,"dim_to_anom","year")
    var := dim_rmvmean_n_Wrap(var, dim_to_anom) 
  end if

  if(method .eq. "std") 
    var := dim_standardize_n_Wrap(var,0, 0) 
  end if

  var := dim_avg_n_Wrap(var,dim_to_mean)
  ; if(isVarMonth) var := dim_avg_n_Wrap(var, "month") end if
  
  ; var0!0 = "year"
  ; var0&year := type@year
  ; var0@name = var_name
    ; print(var0@mon_name)
  if((call_stream[0] .eq. call_process) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(var,id)
  end if
  return(var)
end

undef("getJetLat")
function getJetLat(U)
local lat, ind_lon,jet_lat
begin
  lat = U&lat
  ind_lon = dim_maxind(U, 0)
  jet_lat = avg(lat(ind_lon))
  return jet_lat
end

undef("getJetLats")
function getJetLats(U)
local lat, ind_lon,jet_lat
begin
  lat = U&lat
  ind_lon = dim_maxind(U, 0)
  jet_lat = lat(ind_lon)
  setDim(jet_lat,0,"lon",U&lon)
  return jet_lat
end

undef("getJetAxisStrength")
function getJetAxisStrength(U)
local lat, ind_lon,jet_lat,jet_strength,jet_strength_lon
begin
  lat = U&lat
  jet_strength_lon = dim_max_n_Wrap(U, 0)
  jet_strength = dim_avg_Wrap(jet_strength_lon)
  return jet_strength
end

undef("getJetAxis")
function getJetAxis(U)
local lat, ind_lon,jet_lat
begin
  lat = U&lat
  ind_lon = dim_maxind(U, 0)
  jet_lat = lat(ind_lon)
  copy_VarCoords(U(0,:), jet_lat)
  return jet_lat
end

undef("run_cor")
function run_cor(x, y, wSize)
local nyear,half,i,ts,tem_x,tem_y
begin
  nyear = dimsizes(x)
  half = (wSize-1)/2
  ts = new(nyear,"float")
  do i = half, nyear-half-1
    if(isatt(wSize, "designal"))then
      ; print(escorc(y(i-half:i+half), wSize@designal(i-half:i+half)))
      tem_x = designal(x(i-half:i+half),wSize@designal(i-half:i+half))
      tem_y = designal(y(i-half:i+half),wSize@designal(i-half:i+half))
      if(isatt(wSize, "designal1"))then
        tem_x = designal(tem_x,wSize@designal1(i-half:i+half))
        tem_y = designal(tem_y,wSize@designal1(i-half:i+half))
      end if
      ; print("designal")
      ; print(escorc(tem_x, wSize@designal(i-half:i+half)))
      ts(i) = escorc(tem_x,tem_y)
    else
      ts(i) = escorc(x(i-half:i+half),y(i-half:i+half))
    end if
    ; cor_tx_EA_EUA(i) = escorc(tx_EA(i-half:i+half),tx_EUA(i-half:i+half))
    ; cor_tx_EA_EUB(i) = escorc(tx_EA(i-half:i+half),tx_EUB(i-half:i+half))
  end do
  copy_VarCoords(x, ts)
  return ts
end

undef("run_stddev")
function run_stddev(ts,wSize)
local nyear,half,i,rd,indDimYear,dims
begin
  indDimYear = ind(getvardimnames(ts) .eq. "year")
  dims = dimsizes(ts)
  if(indDimYear .gt. 0)then;说明至少是二维的
    nyear = dimsizes(ts&year)
    half = (wSize-1)/2
    rd = new(dims,"float")
    if(dimsizes(dims) .eq. 2)then
      do i = half, nyear-half-1
        rd(:,i) = dim_stddev_n(ts(:,i-half:i+half), 1)
      end do
      copy_VarCoords(ts, rd)
      return rd
    end if
  end if
  nyear = dimsizes(ts)
  half = (wSize-1)/2
  rd = new(nyear,"float")
  do i = half, nyear-half-1
    rd(i) = stddev(ts(i-half:i+half))
  end do
  copy_VarCoords(ts, rd)
  return rd
end

undef("run_num")
function run_num(ts,wSize)
local nyear,half,i,rd,indDimYear,dims
begin
  indDimYear = ind(getvardimnames(ts) .eq. "year")
  dims = dimsizes(ts)
  if(indDimYear .gt. 0)then;说明至少是二维的
    nyear = dimsizes(ts&year)
    half = (wSize-1)/2
    rd = new(dims,"float")
    if(dimsizes(dims) .eq. 2)then
      do i = half, nyear-half-1
        rd(:,i) = dim_num_n(ts(:,i-half:i+half), 1)
      end do
      copy_VarCoords(ts, rd)
      return rd
    end if
  end if
  nyear = dimsizes(ts)
  half = (wSize-1)/2
  rd = new(nyear,"float")
  do i = half, nyear-half-1
    rd(i) = dim_num_n(ts(i-half:i+half),1)
  end do
  copy_VarCoords(ts, rd)
  return rd
end

undef("run_cor_dev")
function run_cor_dev(x, y, wSize)
local nyear,half,i,ts,isDetrend
begin
  nyear = dimsizes(x)
  dimY = dimsizes(y)
  ndimY = dimsizes(dimY)
  half = (wSize-1)/2
  isDetrend = get_res_value_keep(wSize,"detrend",False)
  if(ndimY .eq. 1)then
    ts = new(dimY,"float")
    do i = half, nyear-half-1
      if(isDetrend)then
        ts(i) = escorc(dtrend(x(i-half:i+half), True),dtrend(y(i-half:i+half), True))
      else
        ts(i) = escorc(x(i-half:i+half),y(i-half:i+half))
      end if
    end do
    copy_VarCoords(y, ts)
    return ts
  elseif(ndimY .eq. 2)then
    ts = new(dimY,"float")
    do i = half, nyear-half-1
      if(isDetrend)then
        ts(i,:) = escorc_n(dtrend_n(x(i-half:i+half), True,0),dtrend_n(y(i-half:i+half,:), True,0),0,0)
      else
        ts(i,:) = escorc_n(x(i-half:i+half),y(i-half:i+half,:),0,0)
      end if
    end do
    copy_VarCoords(y, ts)
    return ts
  elseif(ndimY .eq. 3)then
    ts = new(dimY,"float")
    do i = half, nyear-half-1
      if(isDetrend)then
        ts(i,:,:) = escorc_n(dtrend_n(x(i-half:i+half), True,0),dtrend_n(y(i-half:i+half,:,:), True,0),0,0)
      else
        ts(i,:,:) = escorc_n(x(i-half:i+half),y(i-half:i+half,:,:),0,0)
      end if
    end do
    copy_VarCoords(y, ts)
    return ts
  end if
end

undef("run_reg")
function run_reg(x[*], y, wSize)
local nyear,half,ts,i
begin
  nyear = dimsizes(x)
  half = (wSize-1)/2
  ts = new(nyear,"float")
  multiple = get_res_value_keep(wSize,"multiple",1.)
  do i = half, nyear-half-1
    ts(i) = regCoef(x(i-half:i+half),y(i-half:i+half))*multiple
  end do
  copy_VarCoords(y, ts)
  return ts
end

undef("run_reg_dev")
function run_reg_dev(x[*], y, wSize)
local nyear,half,ts,i
begin
  nyear = dimsizes(x)
  dimY = dimsizes(y)
  ndimY = dimsizes(dimY)
  half = (wSize-1)/2
  if(ndimY .eq. 1)then
    ts = new(dimY,"float")
    multiple = get_res_value_keep(wSize,"multiple",1.)
    do i = half, nyear-half-1
      ts(i) = regCoef(x(i-half:i+half),y(i-half:i+half))*multiple
    end do
    copy_VarCoords(y, ts)
    return ts
  elseif(ndimY .eq. 2)then
    ts = new(dimY,"float")
    multiple = get_res_value_keep(wSize,"multiple",1.)
    do i = half, nyear-half-1
      ts(i,:) = regCoef_n(x(i-half:i+half),y(i-half:i+half,:),0,0)*multiple
    end do
    copy_VarCoords(y, ts)
    return ts
  elseif(ndimY .eq. 3)then
    ts = new(dimY,"float")
    multiple = get_res_value_keep(wSize,"multiple",1.)
    do i = half, nyear-half-1
      ts(i,:) = regCoef_n(x(i-half:i+half),y(i-half:i+half,:,:),0,0)*multiple
    end do
    copy_VarCoords(y, ts)
    return ts
  end if
end

undef("run_trend")
function run_trend(x[*], wSize)
local nyear,half,ts,ts_sig,i,y,t,tem,tval
begin
  nyear = dimsizes(x)
  y = ispan(1, wSize, 1)
  t := t_value(wSize-2)
  half = (wSize-1)/2
  ts = new(nyear,"float")
  tval = new(nyear,"float")
  multiple = get_res_value_keep(wSize,"multiple",1.)
  do i = half, nyear-half-1
    tem := regCoef(y,x(i-half:i+half))
    ts(i) = tem*multiple
    tval(i) = tem@tval
  end do
  copy_VarCoords(x, ts)
  ts@tval = tval

  return ts
end

undef("bandpass")
  function bandpass(ts,ca,cb,opt); ca和cb分别为滤波的范围，即ca-cd
  local fca,fcb,dims,ID,IA,ts0
  begin
  
    fca     = 1.0/ca
    fcb     = 1.0/cb
    dims    = 0
    opt@return_envelope = False                  ; time series of filtered *and* envelope values
    opt@remove_mean = True
    ; printVarSummary(ts)
    ID    = bw_bandpass_filter (ts,fca,fcb,opt,dims)  ; index of decadel
    IA = ts-ID
    ; opt@filename="filter/"+opt@filename
    ; opt@trend = False
    ; opt@rm = 0
    ts0=IA
    ts0!0="year"
    ts0&year=ts&year
    opt@nameL="IA"
    opt@nameR="ID"
    ; opt@legend = True
    opt@gsnLeftString="bandpass"
    ; plot = plot_ts(wks,ts0,0,opt)
    return(ts0)
  end

undef("EOF"); FX| EOF
function EOF(X,opt)
local res,dimName,lat_list,isLat,lat_name,wgt,Xw,eof0,eof,eval,eof_ts,rev
begin
  res = True
    res@jopt = 0
    res@neof = 2
    res@reof = False
    res@rev = (/1,1,1,1/)
    res@weight = True
    res@return_mode = False
  copy_VarAtts(opt,res)
  if(isatt(X, "name"))then
    print("calculate EOF of "+X@name)
  end if
  dimName = getvardims(X)
  lat_list = (/"lat","Lat","latitude","Latitude"/);可能的纬度名
  isLat = isdim(X,lat_list); 判断X中是否存在纬度

  if(any(isLat) .and. res@weight)then
    lat_name = lat_list(ind(isLat)) ;获得纬度名
    wgt = sqrt(cos(X&$lat_name$*0.01745329));获得权重
    Xw = X*conform(X, wgt, ind(dimName .eq. lat_name)); 加权
    copy_VarCoords(X, Xw)
    printx("data weighted before EOF")
    else
    Xw = X
  end if
  eof0    = eofunc_n_Wrap(Xw, res@neof, res,0)
  ; print(eof0@eval)
  if(res@reof)then
    eof = eofunc_varimax_Wrap(eof0, 1);方差最大分析，即在EOF的基础上对主模态旋转
    eofunc_varimax_reorder(eof); 按方差大小重新排序
    eval         = eof@variance_varimax
    eof_ts       = eofunc_ts_n_Wrap(Xw, eof, res,0); 获得pc
    eof_ts@pcvar = eof@pcvar_varimax; 解释方差
  else
    eof = eof0
    eval    = eof@eval
    eof_ts = eofunc_ts_n_Wrap(Xw, eof, res,0)
    eof_ts@pcvar = eof@pcvar
  end if

  rev = conform(eof_ts,res@rev(:res@neof-1),0)
  ; eval := conform(eof,eval,0)
  ; eof = (/eof*rev*eval/)
  ; printVarSummary(eof_ts)
  eof_ts := dim_standardize_n_Wrap(eof_ts, 0, 1)
  eof_ts = (/eof_ts*rev/)

  ; do n=0,opt@neof-1
  ;   if(dimsizes(dimsizes(X)) .eq. 2)
  ;     eof(n,:)=opt@rev(n)*sqrt(eval(n))*eof(n,:)
  ;     else
  ;     eof(n,:,:)=opt@rev(n)*sqrt(eval(n))*eof(n,:,:)
  ;   end if
  ;   eof_ts(n,:)=opt@rev(n)*eof_ts(n,:)/sqrt(eval(n))
  ; end do

  eof_ts@name=X@name
  eof_ts&year=X&year
  eof_ts@reof     = res@reof
  if(res@return_mode)
    eof_ts@mode = eof
  end if
  return(eof_ts)
end

undef("SVD")
function SVD(L,R,opt)
local color,ak_std,bk_std,ccr,ts_pairs,nsvd,nyears,L_size,n_L_size,homlft,hetlft,L_ano,R_size,n_R_size,homrgt,hetrgt,R_ano0,R_ano,xmsg,ak,bk,ccr_ak,ccr_bk
begin
  call_SVD = "SVD"
  ListAppend(call_stream, call_SVD)
  ; printVarSummary(L)
  id_L = True
  copy_VarAtts_match(L,id_L,(/"name","month","year","range","level","source"/),"level_indicator")
  id_L@call = call_SVD

  id_R = True
  copy_VarAtts_match(R,id_R,(/"name","month","year","range","level","source"/),"level_indicator")
  id_R@call = call_SVD

  if(call_stream[0] .eq. call_SVD .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffers([/id_L,id_R/]))
    color = "blue"
      ; color@dashLineOn = False
    printc("read buffer: "+call_SVD,color)
    ak_std = read_buffer(id)
    bk_std = read_buffer(id)
    ccr = escorc_n(ak_std, bk_std, 1, 1)
    ts_pairs = [/ak_std,bk_std,ccr/]
    return(ts_pairs)
  end if
  nsvd = get_res_value_keep(opt,"nsvd",2)
  nyears = dimsizes(L&year)
  ;把数据reshape成二维
  L_size   = dimsizes(L)
  n_L_size = L_size(1)*L_size(2)
  homlft      = new((/nsvd,n_L_size/),float)
  hetlft      = new((/nsvd,n_L_size/),float)
  L_ano    = reshape(L,(/L_size(0),n_L_size/))
  L_ano!0  = "time" 
  L_ano!1  = "pts"
  
  R_size   = dimsizes(R)
  n_R_size = R_size(1)*R_size(2)
  homrgt      = new((/nsvd,n_R_size/),float)
  hetrgt      = new((/nsvd,n_R_size/),float)
  R_ano0    = reshape(R,(/R_size(0),n_R_size/))
  R_ano0!0  = "time" 
  R_ano0!1  = "pts" 
  R_ano=R_ano0
  R_ano@_FillValue=L_ano@_FillValue
  R_ano=where(R_ano0 .eq. R_ano0@_FillValue,R_ano@_FillValue,R_ano0)
  xmsg        = -999.9                             ; missing value
  x           = svdcov(L_ano(pts|:,time|:),R_ano(pts|:,time|:),nsvd,homlft,hetlft,homrgt,hetrgt)
  ak          = -1*onedtond(x@ak,(/nsvd,nyears/))
  bk          = -1*onedtond(x@bk,(/nsvd,nyears/))
  ak!0        = "sv"
  ak!1        = "year"
  bk!0        = "sv"
  bk!1        = "year"
  
  ccr_ak      = -1*reshape(hetrgt(0,:),(/R_size(1),R_size(2)/))
  ccr_bk      = -1*reshape(hetlft(0,:),(/L_size(1),L_size(2)/))
  copy_VarCoords(R(0,:,:), ccr_ak)
  copy_VarCoords(L(0,:,:), ccr_bk)
   ccr_ak      = where(R(0,:,:) .eq. R@_FillValue,ccr_ak@_FillValue,ccr_ak)
  ccr = escorc_n(ak, bk, 1, 1)
  ak_std = dim_standardize_Wrap(ak,1)
  ak_std&year = L&year
  bk_std = dim_standardize_Wrap(bk,1)
  bk_std&year = L&year
  ts_pairs = [/ak_std,bk_std,ccr,x/]
  if((call_stream[0] .eq. call_SVD) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(ak_std,id_L)
    write_buffer(bk_std,id_R)
  end if
  ; ts = (/ak_std,bk_std/) ; ts为三维数组，第一维表示左右场，第二维表示第几对模态，第三维为时间
  return(ts_pairs)
end

undef("areavg")
function areavg(var)
local d2r,lat_wgt,var_avg
begin
  d2r = get_d2r("float")
  lat_wgt = cos(var&lat*d2r)
  var_avg = wgt_areaave_Wrap(var, lat_wgt,1, 0)
  return var_avg
end

undef("areavg_dev"); FX| areavg
function areavg_dev (type,method)
local option,id,tem,d2r,lat_wgt,tem_avg,tem
begin
  call_areavg_dev = "areavg_dev"
  ListAppend(call_stream, call_areavg_dev)
  ; printc("start: areavg_dev","green")
  option = method
  option@method = get_res_value_keep(option,"method","anom")
  option@weight = get_res_value_keep(option,"weight",True)
  option@preyear = False
  option@std = get_res_value_keep(option,"std",True)
  option@detrend = get_res_value_keep(option,"detrend",False)
  id = type
    id@type = type
    id@method = option@method
    ; id@dim_to_mean = dim_to_mean
    id@call = call_areavg_dev
    id@weight = option@weight
    id@std = option@std
    id@detrend = option@detrend
  if(call_stream[0] .eq. call_areavg_dev .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
    color = "blue"
      ; color@dashLineOn = False
    printc("read buffer: "+call_areavg_dev,color)
    return(read_buffer(id))
  end if
  tem      = process(type,option)
  if(option@weight)
    print("data is weighted")
    d2r = get_d2r("float")
    ; d2r     = 4.0*atan(1.0)/180 ; rad = 0.01745329
    lat_wgt = cos(tem&lat*d2r)
    ; 法1
    tem_avg = wgt_areaave(tem, lat_wgt,1, 0)
    ; 法2
    ; tem_avg = dim_avg_n_Wrap( dim_avg_wgt_n_Wrap(tem, lat_wgt, 1, 1), 1 )
    ; 法3
    ; temw = tem*conform(tem, lat_wgt, 1);具体哪个维度看情况，一般水平用1
    ;   copy_VarCoords(tem, temw)
    ; tem_avg = dim_avg_n_Wrap(temw,(/1,2/))
  else
    tem_avg = dim_avg_n_Wrap(tem, (/1,2/))
  end if
  copy_VarCoords(tem(:,0,0),tem_avg)

  ; if(option@data .eq. 3) tem_avg@clim = avg(tem_avg) end if

  if(option@std) tem_avg = (/dim_standardize_n(tem_avg,1,0)/) end if
  ; count = ListCount(call_stream)
  ; isEnd(call_areavg_dev,tem_avg)
  ; if(call_stream[0] .eq. call_areavg_dev)
  ;   printc("return to main code","blue")
  ;   call_stream := NewList("fifo")
  ;   print(ListCount(call_stream))
  ; end if
  if((call_stream[0] .eq. call_areavg_dev) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(tem_avg,id)
  end if
  if(isatt(option, "multi"))then
    print("multi")
    tem_avg = (/tem_avg*option@multi/)
  end if
  return(tem_avg)
  end

undef("areavg_CMIP6"); FX| areavg
function areavg_CMIP6 (type,method)
local option,id,color,d2r,lat_wgt,tem_avg,tem
begin
  call_areavg_CMIP6 = "areavg_CMIP6"
  ListAppend(call_stream, call_areavg_CMIP6)
  ; printc("start: areavg_CMIP6","green")
  option = method
  option@method = get_res_value_keep(option,"method","anom")
  option@weight = get_res_value_keep(option,"weight",True)
  option@preyear = False
  option@std = get_res_value_keep(option,"std",True)
  option@detrend = get_res_value_keep(option,"detrend",False)
  id = type
    id@type = type
    id@method = option@method
    ; id@dim_to_mean = dim_to_mean
    id@call = call_areavg_CMIP6
    id@weight = option@weight
    id@std = option@std
    id@detrend = option@detrend
  if(call_stream[0] .eq. call_areavg_CMIP6 .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
    color = "blue"
      ; color@dashLineOn = False
    printc("read buffer: "+call_areavg_CMIP6,color)
    return(read_buffer(id))
  end if
  tem  = process_CMIP6(type,option)
  if(option@weight)
    print("data is weighted")
    d2r = get_d2r("float")
    ; d2r     = 4.0*atan(1.0)/180 ; rad = 0.01745329
    lat_wgt = cos(tem&lat*d2r)
    ; 法1
    tem_avg = wgt_areaave(tem, lat_wgt,1, 0)
    ; 法2
    ; tem_avg = dim_avg_n_Wrap( dim_avg_wgt_n_Wrap(tem, lat_wgt, 1, 1), 1 )
    ; 法3
    ; temw = tem*conform(tem, lat_wgt, 1);具体哪个维度看情况，一般水平用1
    ;   copy_VarCoords(tem, temw)
    ; tem_avg = dim_avg_n_Wrap(temw,(/1,2/))
  else
    tem_avg = dim_avg_n_Wrap(tem, (/1,2/))
  end if
  copy_VarCoords(tem(:,0,0),tem_avg)

  ; if(option@data .eq. 3) tem_avg@clim = avg(tem_avg) end if

  if(option@std) tem_avg = (/dim_standardize_n(tem_avg,1,0)/) end if
  ; count = ListCount(call_stream)
  ; isEnd(call_areavg_CMIP6,tem_avg)
  ; if(call_stream[0] .eq. call_areavg_CMIP6)
  ;   printc("return to main code","blue")
  ;   call_stream := NewList("fifo")
  ;   print(ListCount(call_stream))
  ; end if
  if((call_stream[0] .eq. call_areavg_CMIP6) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(tem_avg,id)
  end if
  return(tem_avg)
end

undef("areavg_CESM2LE"); FX| areavg
function areavg_CESM2LE (type,method)
local option,id,color,d2r,lat_wgt,tem_avg,tem
begin
  call_areavg_CESM2LE = "areavg_CESM2LE"
  ListAppend(call_stream, call_areavg_CESM2LE)
  ; printc("start: areavg_CMIP6","green")
  option = method
  option@method = get_res_value_keep(option,"method","anom")
  option@weight = get_res_value_keep(option,"weight",True)
  option@preyear = False
  option@std = get_res_value_keep(option,"std",True)
  option@detrend = get_res_value_keep(option,"detrend",False)
  id = type
    id@type = type
    id@method = option@method
    ; id@dim_to_mean = dim_to_mean
    id@call = call_areavg_CESM2LE
    id@weight = option@weight
    id@std = option@std
    id@detrend = option@detrend
  if(call_stream[0] .eq. call_areavg_CESM2LE .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
    color = "blue"
      ; color@dashLineOn = False
    printc("read buffer: "+call_areavg_CESM2LE,color)
    return(read_buffer(id))
  end if
  tem  = process_CESM2LE(type,option)
  
  if(option@weight)
    print("data is weighted")
    d2r = get_d2r("float")
    ; d2r     = 4.0*atan(1.0)/180 ; rad = 0.01745329
    lat_wgt = cos(tem&lat*d2r)
    ; 法1
    tem_avg = wgt_areaave(tem, lat_wgt,1, 0)
    ; 法2
    ; tem_avg = dim_avg_n_Wrap( dim_avg_wgt_n_Wrap(tem, lat_wgt, 1, 1), 1 )
    ; 法3
    ; temw = tem*conform(tem, lat_wgt, 1);具体哪个维度看情况，一般水平用1
    ;   copy_VarCoords(tem, temw)
    ; tem_avg = dim_avg_n_Wrap(temw,(/1,2/))
  else
    tem_avg = dim_avg_n_Wrap(tem, (/1,2/))
  end if
  copy_VarCoords(tem(:,0,0),tem_avg)

  ; if(option@data .eq. 3) tem_avg@clim = avg(tem_avg) end if

  if(option@std) tem_avg = (/dim_standardize_n(tem_avg,1,0)/) end if
  ; count = ListCount(call_stream)
  ; isEnd(call_areavg_CMIP6,tem_avg)
  ; if(call_stream[0] .eq. call_areavg_CMIP6)
  ;   printc("return to main code","blue")
  ;   call_stream := NewList("fifo")
  ;   print(ListCount(call_stream))
  ; end if
  if((call_stream[0] .eq. call_areavg_CESM2LE) .and. is_element(bufferMode,(/"write","smart"/)))
    write_buffer(tem_avg,id)
  end if
  return(tem_avg)
end

undef("dim_trend")
function dim_trend(var[*])
local trend,pval_oneSide
begin
  trend = regCoef(ispan(1, dimsizes(var), 1), var)
  pval_oneSide =cdft_p(abs(trend@tval),dimsizes(var)-2)
  trend@pval = (1-pval_oneSide)*2
  return trend
end

undef("dim_trend_n")
function dim_trend_n(var,n)
local dim,trend
begin
  dim = dimsizes(var)
  trend = regCoef_n(ispan(1, dim(n), 1), var,0,n)
  df = trend@tval
  df = dim(n)-2
  pval_oneSide =cdft_p(abs(trend@tval),df)
  trend@pval = (1-pval_oneSide)*2
  copy_VarCoords_not_n(var,trend,n)
  return trend
end

undef("trend_correct")
function trend_correct(var)
local weight,dim,var_correct,i
begin
  weight := (/30,-5,-1,-6,-1,-5,-2,-5,-1,-6,-1,-5,-2,-5,-1,-6,4,0,3,0,4,-1,4,0,3,0,4,-1,4,0,3,0,0,-1,0,0,-1,0,0,-1,0,0,-1,0,0,-1/)
  dim = dimsizes(var)
  var_correct := 30*var(45:)
  do i = 1,45
    var_correct = var_correct+weight(i)*var(45-i:dim-1-i)
  end do
  var_correct = var_correct/31.
  copy_VarCoords(var(45:), var_correct)
  return var_correct
end


undef("trend_correct3D")
function trend_correct3D(var)
local weight,dim,var_correct,i
begin
  weight := (/30,-5,-1,-6,-1,-5,-2,-5,-1,-6,-1,-5,-2,-5,-1,-6,4,0,3,0,4,-1,4,0,3,0,4,-1,4,0,3,0,0,-1,0,0,-1,0,0,-1,0,0,-1,0,0,-1/)
  dim = dimsizes(var)
  var_correct := 30*var(45:,:,:)
  do i = 1,45
    var_correct = var_correct+weight(i)*var(45-i:dim(0)-1-i,:,:)
  end do
  var_correct = var_correct/31.
  copy_VarCoords(var(45:,:,:), var_correct)
  ; copy_VarMeta(var(45,:,:), var_correct)
  copy_VarAtts(var, var_correct)
  return var_correct
end

undef("get_reg")
function get_reg(ts,tp,opt)
local type,method,res,tval,rec,t,nyear,X,exclude
  begin
  type = tp
  ; call_add_reg = "add_reg"
  ; ListAppend(call_stream, call_add_reg)
  ; printc("start: add_reg","green")
  method = "anom"
  if(isatt(opt, "add_dim_to_mean"))
    method@add_dim_to_mean = opt@add_dim_to_mean
  end if
  if(isatt(opt, "detrend"))
    method@detrend = opt@detrend
  end if
    ; res@cnFillDrawOrder = "predraw"
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  ; opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ; type@source = "jra55"
  type@year := ts&year
  ; type@range := range
  type@ts = ts
  ; opt@lonP0=False 
  ; opt@vertical=False
  ; if(isatt(opt,"polar")) range(2:3) = (/0,360/) end if
  ; id = type
  ;   id@type = type
  ;   ; id@dim_to_mean = dim_to_mean
  ;   id@call = call_add_reg
  ;   if(isatt(opt,"add_dim_to_mean"))
  ;     id@add_dim_to_mean = opt@add_dim_to_mean
  ;   end if
  ; if(call_stream[0] .eq. call_add_reg .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
  ;     printc("read buffer: "+call_add_reg,"blue")
  ;     rec := read_buffer
  ; else
    if(isatt(opt, "focusIA"))then
      type@year := ispan(1950, 2022, 1)
      X := process(type,method)
      if(isatt(opt,"multi")) X = (/X*opt@multi/) end if
      tem := bandpass(X,10,200,True)
      rec := regCoef_n(ts, tem({ts&year},:,:), 0, 0)
    else
      X := process(type,method)
      if(isatt(opt,"multi")) X = (/X*opt@multi/) end if
      if(isatt(opt, "designal"))then
        print("designal")
        X = (/designal(X,opt@designal)/)
      end if
      rec := regCoef_n(ts, X, 0, 0)
    end if
    if(isatt(opt, "relative") .and. opt@relative)then
      method = "stddev"
      X_clim = process(type,method)
      if(isatt(opt,"multi")) X = (/X*opt@multi/) end if
      tem := where(X_clim .eq. 0, X_clim@_FillValue, X_clim)
      rec = (/rec/tem/)
      rec@units = "%"
    end if
    ; printVarSummary(X)
    copy_VarCoords_not_n( X, rec, 0)

    ; if((call_stream[0] .eq. call_add_reg) .and. is_element(bufferMode,(/"write","smart"/)))
    ;   write_buffer(rec,id)
    ; end if
  ; end if
  ; if(isatt(opt,"multi")) rec = (/rec*opt@multi/) end if
  tval = get_tval(rec)
  if(get_res_value_keep(opt,"smoothing",False));平滑
    rec := smth9_Wrap(rec, 0.25, 0.5, False)
  end if

  if(get_res_value_keep(opt,"onlySignificant",False));只画显著区域
    rec_sig = where(abs(tval) .ge. t@t90,rec,rec@_FillValue)
    rec = (/rec_sig/)
  end if
  return rec
end

; 参数：位势高度场异常，气温场气候态，u风场气候态，v风场气候态（注意都是空间场，不应带有时间维），层次（hPa）
undef("waf_2D")
function waf_2D(zavar,ctvar,cuvar,cvvar,level)
local lat,lon,nlat,nlon,ga,re,pi,f,leveltmp,ftmp,lattmp,coslattmp,cumag,psidev,dpsidevdlon,ddpsidevdlonlon,dpsidevdlat,ddpsidevdlonlat,ddpsidevdlatlat,xuterm,xvterm,yvterm,Fx,Fy
begin
  ;考虑加个兼容性部分
  lat = zavar&lat
  lon = zavar&lon

  nlat = dimsizes(lat)
  nlon = dimsizes(lon)

  ; 部分常数
  ;  Gravitational acceleration
  ga=9.80665
  ;  Radius of the earth
  re=6378388
  ; 圆周率，用get_pi()也可以
  pi = atan(1.0)*4.

  ;度数转弧度
  lat_rad = lat*pi/180.
  lon_rad = lon*pi/180.

  ; 1-D -> 2-D
  leveltmp = new(dimsizes(zavar), typeof(zavar))
  leveltmp = level/1000.
  lattmp = conform_dims(dimsizes(zavar),lat,0)
  coslattmp = cos(lattmp*pi/180.)

  ; Coriolis parameter
  ; 热带地区地转偏向力过小，会造成波活动通量过大，因此将其屏蔽
  f =  2.*2.*pi/(60.*60.*24.)*sin(pi/180. * lat(:))
  f!0 = "lat"
  f&lat = lat
  f@_FillValue = zavar@_FillValue
  ftmp = conform_dims(dimsizes(zavar),f,0)
  ftmp = where(abs(lattmp) .lt. 10,ftmp@_FillValue,ftmp)

  ; magnitude of climatological wind
  ; 气候态的全风速
  cumag = sqrt(cuvar^2 + cvvar^2)
  cumag@_FillValue = cuvar@_FillValue
  cumag = where(cumag .gt. 0, cumag, cumag@_FillValue)

  ; QG steam function for anomaly
  ; 位势高度场转为准地转流函数
  psidev = zavar*ga /ftmp

  ;dpsidev/dlon
  dpsidevdlon =  center_finite_diff_n(psidev,lon_rad,True,0,1)

  ;ddpsidev/dlonlon
  ddpsidevdlonlon =  center_finite_diff_n(dpsidevdlon,lon_rad,True,0,1)

  ;dpsidev/dlat
  dpsidevdlat = center_finite_diff_n(psidev, lat_rad, False,0,0)

  ;ddpsidev/dlonlat
  ddpsidevdlonlat =  center_finite_diff_n(dpsidevdlon,lat_rad,False,0,0)

  ;ddpsidev/dlatdlat
  ddpsidevdlatlat = center_finite_diff_n(dpsidevdlat, lat_rad,False,0,0)

  xuterm = (dpsidevdlon*dpsidevdlon - psidev*ddpsidevdlonlon)
  xvterm = (dpsidevdlon*dpsidevdlat - psidev*ddpsidevdlonlat)
  ;yuterm = xvterm
  yvterm = (dpsidevdlat*dpsidevdlat - psidev*ddpsidevdlatlat)

  ; Mask out where westerlies is small or negative (less than 5 m/s). by using mask
  ; 用mask屏蔽西风带小于5m/s的部分

  ;x-component of (38)
  Fx = mask(leveltmp/(2.*cumag*re*re)*( cuvar/coslattmp * xuterm + cvvar * xvterm), cuvar.lt.0,False)

  ;y-component 
  Fy = mask(leveltmp/(2.*cumag*re*re)*( cuvar*xvterm + coslattmp * cvvar * yvterm), cuvar.lt.0,False)

  copy_VarCoords(zavar, Fx)
  copy_VarCoords(zavar, Fy)

  Fx@units = "m^2/s^2"
  Fy@units = "m^2/s^2"
  ;返回波活动通量的x，y分量
  return[/Fx,Fy/]
end