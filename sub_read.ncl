undef("type_and_keys")
function type_and_keys(text)
local type
begin
  type = systemfunc("echo '"+text+"' | jq -c '[type,keys]'")
  return str_split(type, "[],"+str_get_dq())
end
undef("convertValue")
function convertValue(v,type)
local value_len,tem,value,v
begin
  v = str_squeeze(v)
  if(type .eq. "")then
    type = str_split(systemfunc("echo '"+v+"'|jq -c 'type'"), str_get_dq())
  end if
  if(type .eq. "object")then
    ; print("object")
    return v
  end if
  if(type .eq.  "string")then
    return str_split(v,str_get_dq()+",")
  end if
  if(type .eq.  "number")then
    if(isStrSubset(v, "."))then
      tem := stringtofloat(v)
    else
      tem := stringtoint(v)
    end if
    return tem
  end if
  tem := str_split(v, "[],"+str_get_dq())
  if(all(is_string_numeric(tem)))then
    if(isStrSubset(v, "."))then
      tem := stringtofloat(tem)
    else
      tem := stringtoint(tem)
    end if
  end if
  return tem
end
undef("parse")
function parse(path,objectName)
local f,tem,res,i,keys,type,nKeys,types,pairs,typeInd,res,text
begin
  if(fileexists(path))then
    f = systemfunc("jq -c '."+objectName+"' "+path)
  else
    f = systemfunc("echo '"+path+"'|jq -c '."+objectName+"'")
  end if
  if(ismissing(f))then
    print("missing")
    return f
  end if
  tem := type_and_keys(f)
  type = tem(0)
  keys = tem(1:)
  if(type .eq. "object")then
    nKeys = dimsizes(keys)
    types = new(nKeys, string)
    pairs = systemfunc("echo '"+f+"'|jq '["+str_join("."+keys, ",")+"]|map([.,type])'")
    pairs := str_sub_str(pairs, "    },", "}")
    typeInd = ind(pairs .eq. "  ],")-1
    types(:dimsizes(typeInd)-1) = pairs(typeInd)
    types(nKeys-1) = pairs(dimsizes(pairs)-3)
    types = str_squeeze(types)
    res = True
    text = str_join(pairs(2:typeInd(0)-1), "")
    res@$keys(0)$ = convertValue(text,str_split(types(0), str_get_dq()))
    if(nKeys .eq. 1) return res end if

    text = str_join(pairs(typeInd(nKeys-2)+3:dimsizes(pairs)-4), "")
    res@$keys(nKeys-1)$ = convertValue(text,str_split(types(0), str_get_dq()))
    if(nKeys .eq. 2) return res end if

    do i = 1,nKeys-2
      text = str_join(pairs(typeInd(i-1)+3:typeInd(i)-1), "")
      res@$keys(i)$ = convertValue(text,str_split(types(i), str_get_dq()))
    end do
    return res
  else
    tem := convertValue(f,type)
    return tem
  end if
end

undef("extract")
function extract(X,qlon,qlat)
local dimName,dims,ind_lat,ind_lon,lat,lon,X_in
begin 
  dims = dimsizes(X)
  dimName = getvardimnames(X)
  ind_lat = ind(dimName .eq. "lat")
  ind_lon = ind(dimName .eq. "lon")
  lat = conform_dims(dims, X&lat, ind_lat)
  lon = conform_dims(dims, X&lon, ind_lon)
  X_in = where(gc_inout(lat, lon, qlat, qlon), X, X@_FillValue)
  copy_VarCoords(X, X_in)
  return(X_in)
end

undef("read_sc")
function read_sc(type, opt)
local f,land,time,year,month,day,range,i
begin
  f = addfile("/Users/linlifei/data/sc.nc","r")
  ; f = addfile("/Users/linlifei/data/G10035-rutgers-nh-24km-weekly-sce-v01r00-19800826-20210906.nc","r"); 从1980年9月开始
  ; print(f)
  ; lat = f->latitude
  ; lon = f->longitude
  land = f->land
  time = cd_calendar(f->time,0)
  year = time(:,0)
  month = time(:,1)
  day = time(:,2)
  range = type@range
  week_ind = ind((year .ge. min(type@year) .and. year .le. max(type@year)) .and. (month .ge. min(type@month) .and. month .le. max(type@month)))
  ; print(week_ind)

  tem = f->snow_cover_extent(week_ind,{range(0):range(1)},{range(2):range(3)})
  dims = dimsizes(tem)
  sc = new((/dimsizes(type@year),dims(1),dims(2)/),float)
  tem&time = cd_calendar(tem&time,-1)/100
  do i = 0, dimsizes(type@year)-1, 1
    sc(i,:,:) = dim_avg_n_Wrap(tem(ind(tem&time .eq. type@year(i)),:,:),0)
  end do
  sc = (/sc*100/)
  sc!0 = "year"
  sc&year = type@year
  return(sc)
end

undef("read_JA_HW")
function read_JA_HW (tp,opt)
local type,range,year,types,paths,var_name,f,lon,centerLon,lon3,tem0,tem1,lon_ind,dimsize,var_lon
begin
  type = tp
  types = (/"tx90p",  "tx95p",  "tx10p",  "tx5p",  "tn90p",  "tn95p",  "tn10p",  "tn5p","tx90pInt"/)
  paths = (/"tmax90p","tmax95p","tmax10p","tmax5p","tmin90p","tmin95p","tmin10p","tmin5p","tx90pInt"/)
  var_names = (/"tmax90p",  "tx95p",  "tx10p",  "tx5p",  "tn90p",  "tn95p",  "tn10p",  "tn5p","tx90pInt"/)
  if(is_element(type,types))
    type_ind = ind(types .eq. type)
    ; var_name = var_names(type_ind)
    if(type@source .eq. "CPC")
      var_name = "tmax90p"
      path = localpath(2)+"CPC/T_daily/"+paths(type_ind)+".fre.JA.1979_2022.nc"
    elseif(str_upper(type@source) .eq. "ERA5")
      path = localpath(2)+"ERA5_daily/tx/tx90p.fre.JA.1950_2022.nc"
      if(type .eq. "tx90p")then
        var_name = "tx90p_fre"
      elseif(type .eq. "tx90pInt")
        var_name = "tx90p_cum"
      end if
    end if
  elseif(type .eq. "chw")
    path = localpath(2)+"CPC/CHW.fre.JA.1979_2022.nc"
    var_name = "chw"
  elseif(type .eq. "net90p")
    path = localpath(2)+"ERA5_daily/land/ETHW/net90p.fre.JA.1950_2022.nc"
    var_name = "net90p_fre"
  elseif(type .eq. "net90pInt")
    path = localpath(2)+"ERA5_daily/land/ETHW/net90p.fre.JA.1950_2022.nc"
    var_name = "net90p_cum"
  elseif(type .eq. "net85p")
    path = localpath(2)+"ERA5_daily/land/ETHW/net85p.fre.JA.1950_2022.nc"
    var_name = "net85p_fre"
  elseif(type .eq. "net85pInt")
    path = localpath(2)+"ERA5_daily/land/ETHW/net85p.fre.JA.1950_2022.nc"
    var_name = "net85p_cum"
  elseif(type .eq. "net80p")
    path = localpath(2)+"ERA5_daily/land/ETHW/net80p.fre.JA.1950_2022.nc"
    var_name = "net80p_fre"
  elseif(type .eq. "net80pInt")
    path = localpath(2)+"ERA5_daily/land/ETHW/net80p.fre.JA.1950_2022.nc"
    var_name = "net80p_cum"
  elseif(type .eq. "net75p")
    path = localpath(2)+"ERA5_daily/land/ETHW/netnew75p.fre.JA.1950_2022.nc"
    var_name = "net75p_fre"
  elseif(type .eq. "net75pInt")
    path = localpath(2)+"ERA5_daily/land/ETHW/netnew75p.fre.JA.1950_2022.nc"
    var_name = "net75p_cum"
  elseif(type .eq. "precip90p")
    path = localpath(2)+"CPC/EP/precip90p.fre.JA.1979_2022.nc"
    var_name = "precip90p_fre"
  elseif(type .eq. "precip90pInt")
    path = localpath(2)+"CPC/EP/precip90p.fre.JA.1979_2022.nc"
    var_name = "precip90p_cum"
  elseif(type .eq. "precip85p")
    path = localpath(2)+"CPC/EP/precip85p.fre.JA.1979_2022.nc"
    var_name = "precip85p_fre"
  elseif(type .eq. "precip85pInt")
    path = localpath(2)+"CPC/EP/precip85p.fre.JA.1979_2022.nc"
    var_name = "precip85p_cum"
  elseif(type .eq. "precip80p")
    path = localpath(2)+"CPC/EP/precip80p.fre.JA.1979_2022.nc"
    var_name = "precip80p_fre"
  elseif(type .eq. "precip80pInt")
    path = localpath(2)+"CPC/EP/precip80p.fre.JA.1979_2022.nc"
    var_name = "precip80p_cum"
  elseif(type .eq. "precip75p")
    path = localpath(2)+"CPC/EP/precip75p.fre.JA.1979_2022.nc"
    var_name = "precip75p_fre"
  elseif(type .eq. "precip75pInt")
    path = localpath(2)+"CPC/EP/precip75p.fre.JA.1979_2022.nc"
    var_name = "precip75p_cum"
  elseif(type .eq. "spei90p")
    path = localpath(2)+"SPEI_30days/ED/spei90p.fre.JA.1982_2021.nc"
    var_name = "spei90p_fre"
  elseif(type .eq. "spei90pInt")
    path = localpath(2)+"SPEI_30days/ED/spei90p.fre.JA.1982_2021.nc"
    var_name = "spei90p_cum"
  elseif(type .eq. "spei85p")
    path = localpath(2)+"SPEI_30days/ED/spei85p.fre.JA.1982_2021.nc"
    var_name = "spei85p_fre"
  elseif(type .eq. "spei85pInt")
    path = localpath(2)+"SPEI_30days/ED/spei85p.fre.JA.1982_2021.nc"
    var_name = "spei85p_cum"
  elseif(type .eq. "spei80p")
    path = localpath(2)+"SPEI_30days/ED/spei80p.fre.JA.1982_2021.nc"
    var_name = "spei80p_fre"
  elseif(type .eq. "spei80pInt")
    path = localpath(2)+"SPEI_30days/ED/spei80p.fre.JA.1982_2021.nc"
    var_name = "spei80p_cum"
  elseif(type .eq. "spei75p")
    path = localpath(2)+"SPEI_30days/ED/spei75p.fre.JA.1982_2021.nc"
    var_name = "spei75p_fre"
  elseif(type .eq. "spei75pInt")
    path = localpath(2)+"SPEI_30days/ED/spei75p.fre.JA.1982_2021.nc"
    var_name = "spei75p_cum"
  elseif(type .eq. "spei10p")
    path = localpath(2)+"SPEI_30days/ED/spei10p.fre.JA.1982_2021.nc"
    var_name = "spei10p_fre"
  elseif(type .eq. "spei10pInt")
    path = localpath(2)+"SPEI_30days/ED/spei10p.fre.JA.1982_2021.nc"
    var_name = "spei10p_cum"
  elseif(type .eq. "spei15p")
    path = localpath(2)+"SPEI_30days/ED/spei15p.fre.JA.1982_2021.nc"
    var_name = "spei15p_fre"
  elseif(type .eq. "spei15pInt")
    path = localpath(2)+"SPEI_30days/ED/spei15p.fre.JA.1982_2021.nc"
    var_name = "spei15p_cum"
  elseif(type .eq. "spei20p")
    path = localpath(2)+"SPEI_30days/ED/spei20p.fre.JA.1982_2021.nc"
    var_name = "spei20p_fre"
  elseif(type .eq. "spei20pInt")
    path = localpath(2)+"SPEI_30days/ED/spei20p.fre.JA.1982_2021.nc"
    var_name = "spei20p_cum"
  elseif(type .eq. "spei25p")
    path = localpath(2)+"SPEI_30days/ED/spei25p.fre.JA.1982_2021.nc"
    var_name = "spei25p_fre"
  elseif(type .eq. "spei25pInt")
    path = localpath(2)+"SPEI_30days/ED/spei25p.fre.JA.1982_2021.nc"
    var_name = "spei25p_cum"
  elseif(type .eq. "spei30p")
    path = localpath(2)+"SPEI_30days/ED/spei30p.fre.JA.1982_2021.nc"
    var_name = "spei30p_fre"
  elseif(type .eq. "spei30pInt")
    path = localpath(2)+"SPEI_30days/ED/spei30p.fre.JA.1982_2021.nc"
    var_name = "spei30p_cum"
  elseif(type .eq. "spei35p")
    path = localpath(2)+"SPEI_30days/ED/spei35p.fre.JA.1982_2021.nc"
    var_name = "spei35p_fre"
  elseif(type .eq. "spei35pInt")
    path = localpath(2)+"SPEI_30days/ED/spei35p.fre.JA.1982_2021.nc"
    var_name = "spei35p_cum"
  elseif(type .eq. "drought")
    path = localpath(2)+"SPEI_30days/ED/drought.fre.JA.1982_2021.nc"
    var_name = "drought_fre"
  elseif(type .eq. "CE")
    path = localpath(2)+"CE_new.fre.JA.1982_2021.nc"
    var_name = "CE_fre"
  end if

  range = type@range
  if(isatt(type,"ignoreYear"))
    type@year := pop(type@year,type@ignoreYear)
  end if
  year = type@year
  ; print(path)
  ; path = localpath(2)+"CPC_daily_t/tmax"+percent+"p.fre.JA.1979_2021.nc"
  ; path = "/Volumes/data/CPC_daily_t/tmax"+percent+"p.fre.JA.1979_2021.nc"
  f = addfile(path, "r")
  ; print(f)

  if(isfilevar(f,"lon"))
    lon = f->lon
  else
    lon = f->longitude
  end if
  centerLon = where(min(lon)*max(lon) .ge. 0, 180, 0)
  range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
  range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
  if( (range(2) .ge. centerLon-180) .and. \
      (range(3) .le. centerLon+180));该情况不用分开读取
    var = f->$var_name$({year},{range(0):range(1)},{range(2):range(3)})
  else
  test = f->$var_name$({year},:,:)
    adjust = where(range(2) .lt. centerLon-180,360,0)
    tem0 = f->$var_name$({year},{range(0):range(1)},{range(2)+adjust:centerLon+180})
    tem1 = f->$var_name$({year},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
    lon3 = concat([/lon-360,lon,lon+360/])
    lon3&lon = lon3
    lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
    var_lon = lon3(lon_ind)
    copy_VarAtts(lon,var_lon)
    var := merge([/tem0,tem1/],"lon",var_lon)
    dimsize = dimsizes(dimsizes(var))
    var := changeDimOrder(var,"lon",dimsize-1)
    ; copy_VarAtts(att_tem,var)
    copy_VarAtts(type,var)
  end if
  return var
end

undef("read_JJ_HW")
function read_JJ_HW (tp,opt)
begin
  type = tp
  types = (/"tx90p",  "tx95p",  "tx10p",  "tx5p",  "tn90p",  "tn95p",  "tn10p",  "tn5p"/)
  paths = (/"tmax90p","tmax95p","tmax10p","tmax5p","tmin90p","tmin95p","tmin10p","tmin5p"/)
  type_ind = ind(types .eq. type)
  var_name = paths(type_ind)
  path = localpath(2)+"CPC/T_daily/"+var_name+".fre.JJ.1979_2022.nc"

  range = type@range
  if(isatt(type,"ignoreYear"))
    type@year := pop(type@year,type@ignoreYear)
  end if
  year = type@year
  ; path = localpath(2)+"CPC_daily_t/tmax"+percent+"p.fre.JA.1979_2021.nc"
  ; path = "/Volumes/data/CPC_daily_t/tmax"+percent+"p.fre.JA.1979_2021.nc"
  f = addfile(path, "r")
  if(isfilevar(f,"lon"))
    lon = f->lon
  else
    lon = f->longitude
  end if
  centerLon = where(min(lon)*max(lon) .ge. 0, 180, 0)
  range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
  range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
  if( (range(2) .ge. centerLon-180) .and. \
      (range(3) .le. centerLon+180));该情况不用分开读取
    var = f->$var_name$({year},{range(0):range(1)},{range(2):range(3)})
  else
    adjust = where(range(2) .lt. centerLon-180,360,0)
    tem0 = f->$var_name$({year},{range(0):range(1)},{range(2)+adjust:centerLon+180})
    tem1 = f->$var_name$({year},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
    lon3 = concat([/lon-360,lon,lon+360/])
    lon3&lon = lon3
    lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
    var_lon = lon3(lon_ind)
    copy_VarAtts(lon,var_lon)
    var := merge([/tem0,tem1/],"lon",var_lon)
    dimsize = dimsizes(dimsizes(var))
    var := changeDimOrder(var,"lon",dimsize-1)
    ; copy_VarAtts(att_tem,var)
    copy_VarAtts(type,var)
  end if
  return var
end


; undef("add_reg")
; procedure add_reg (plotid,ts,tp,range,opt)
;   begin
;   type = tp
;   call_add_reg = "add_reg"
;   ListAppend(call_stream, call_add_reg)
;   ; printc("start: add_reg","green")
;   method = "anom"
;   if(isatt(opt, "add_dim_to_mean"))
;     method@add_dim_to_mean = opt@add_dim_to_mean
;   end if
;   currentPlot = plotid@plot
;   res = True
;     if(isatt(plotid,"shadedPlots"))
;       res@cnLinesOn = is_element(currentPlot,plotid@shadedPlots)
;       res@gsnContourNegLineDashPattern = 14
;       res@cnLineThicknessF = 5.
;     else
;       res@cnLinesOn = False
;     end if
;     res@cnFillOn = .not. res@cnLinesOn
;     res@gsnAddCyclic = (range(3)-range(2)) .eq. 360
;     res@gsnDraw = False
;     res@gsnFrame = False
;     res@lbLabelBarOn = True
;     res@lbOrientation = "Horizontal"
;     res@gsnStringFontHeightF = 0.027
;     res@cnLevels = (/-4.,-3,-2,-1,1,2,3,4/)
;     res@Scale = 1.
;   exclude = (/"gsnLeftStrings","gsnCornerStrings"/)

;   copy_VarAtts_match(opt,res,res_plot,exclude)
;     ; res@cnFillDrawOrder = "predraw"
;   ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
;   nyear     = dimsizes(ts&year)
  
;   ; opt@preyear = get_res_value_keep(opt,"preyear",False)
;   t = t_value(nyear-2)
;   ; type@source = "jra55"
;   type@year := ts&year
;   type@range := range
;   type@ts = ts
;   ; opt@lonP0=False 
;   ; opt@vertical=False
;   ; if(isatt(opt,"polar")) range(2:3) = (/0,360/) end if
;   id = type
;     id@type = type
;     ; id@dim_to_mean = dim_to_mean
;     id@call = call_add_reg
;   if(call_stream[0] .eq. call_add_reg .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
;       printc("read buffer: "+call_add_reg,"blue")
;       rec := read_buffer
;   else
;     X := process(type,method)
;     ; printVarSummary(X)
;     rec := regCoef_n(ts, X, 0, 0)
;     copy_VarCoords_not_n( X, rec, 0)

;     ; tval = reshape(rec@tval,dimsizes(rec))
;     if((call_stream[0] .eq. call_add_reg) .and. is_element(bufferMode,(/"write","smart"/)))
;       write_buffer(rec,id)
;     end if
;     ; copy_VarCoords(rec,tval)
;   end if
;   if(isatt(opt,"multi")) rec = (/rec*opt@multi/) end if
;   tval = get_tval(rec)
;   if(get_res_value_keep(opt,"smoothing",False));平滑
;     rec := smth9_Wrap(rec, 0.5, 0.5, False)
;   end if

;   if(get_res_value_keep(opt,"onlySignificant",False));只画显著区域
;     rec_sig = where(abs(tval) .ge. t@t90,rec,rec@_FillValue)
;     rec = (/rec_sig/)
;   end if
;   ; cor := smth9_Wrap(cor, 0.5, 0., False)

;   ; cor@cnLevels         = (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)
;     ; cor@cnLevels         = (/-0.9,-0.7,-0.5,-0.3,0.3,0.5,0.7,0.9/)
;   ; cor@cnLevels         := (/-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99/)

;   ; rec@cnFillColors = (/clr(0),clr(1),clr(3),clr(4),clr(5),clr(7),clr(8)/)

;   ; res@cnLevels := (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)


;   res@gsnLeftString = ""
;   if(isatt(opt,"reverseColors")) res@reverseColors = opt@reverseColors end if
;   multi_rec = rec
;   add_cn(plotid,rec,range,res)

;   res_test = get_res_value_keep(opt,"test",True)
;   if(res_test)
;     res_test@mode = get_res_value_keep(opt,"mode","stippling")
;     res_test@cnFillDotSizeF = 0.0025
;     res_test@cnFillScaleF = 1.2
;     ; res_test@stipplingColor = "black"
;     exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)

;     copy_VarAtts_match(opt,res_test,res_plot,exclude)

;     ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
;     ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
;     if(res_test@mode .eq. "stippling")
;       if(isatt(opt,"stipplingColor"))
;         res_test@stipplingColor = opt@stipplingColor
;       end if
;       res_test@cnLevel = t@t90
;       add_dots(plotid,tval,range,res_test)
;     end if

;     if(res_test@mode .eq. "contour")
;       res_test@cnFillOn = False
;       res_test@cnLinesOn = True
;       res_test@lbLabelBarOn = False
;       res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
;       add_cn(plotid,tval,range,res_test)
;     end if
;   end if
; end

undef("read_var_path")
function read_var_path(var)
local test,source_ind,source_list,loc,line,isLast,path,tem,pres,var_path,path,start,ind_year
begin
  test = asciiread(localpath(3)+"config.txt", -1, "string")
  source_ind = str_match_ind(test, "Source")
  source_list = test(source_ind)
  loc = str_match_ind(source_list, str_upper(" "+var@source+","))
  if(ismissing(loc))
    printc(var@source+" is not found","red")
  end if
  
  line = source_ind(loc)
  isLast = loc .eq. dimsizes(source_list)-1
  path = str_get_field(test(line+1),2," ")
  tem = str_get_field(test(line+3),2," ")
  pres = stringtointeger(str_split(tem, ","))
  if(isLast)
    vars = test(line+4:)
  else
    vars = test(line+4:source_ind(loc+1)-2)
  end if
  var_ind = str_match_ind_regex(vars, "^"+str_upper(var)+" ")
  if(ismissing(var_ind))
    ; print(var)
    printc(str_upper(var)+" is not found","red")
  end if
  var_path = str_get_field(vars(var_ind),4," ")
  var@var = str_get_field(vars(var_ind),3," ")
  path = localpath(2)+path+var_path
  start = stringtointeger(str_get_field(test(line+2),2," "))
  if(start .gt. var@year(0))
    printx("the first year is changed to "+start)
    var@year := var@year(start-var@year(0):)
  end if

  if(.not. isStrSubset(path,"nc"))
    path := systemfunc("ls "+path+"*.nc")
    start_str = str_get_field(path(0), 3, ".")
    start_int = stringtoint(start_str)
    ; print(start_int)
    ind_year := tointeger(var@year)-start_int
    if(isArray(pres))
      path@pres = pres
    end if
    return(path(ind_year))
  end if
  ; print(pres)
  if(isArray(pres))
    path@pres = pres
  end if
  return(path)
end

; undef("read_var_path")
; function read_var_path(var)
; local test,source_ind,source_list,loc,line,isLast,path,tem,pres,var_path,path,start,ind_year,f
; begin
;   path = systemfunc("jq '."+str_upper(var@source)+".Path' test.json")
;   path := str_split(path, str_get_dq())
;   var_path = systemfunc("jq -c '."+str_upper(var@source)+"."+str_upper(var)+".Path' test.json")
;   var_path := str_split(var_path, str_get_dq())
;   pres = systemfunc("jq -c '."+str_upper(var@source)+".Pres' test.json")
;   pres := stringtointeger(str_split(pres, "[],"))
;   path := localpath(2)+path+var_path+var@year+".nc"
;   path@pres = pres
;   return path
; end

undef("read_topo")
function read_topo(file_path,var_name,range)
local f,isFileLevel,lon,centerLon,var
begin
  f = addfile(file_path,"r")
  ; print(f)
  isFileLevel = isfilevar(f,"level") .or. isfilevar(f,"lev")
  if(isfilevar(f,"lon"))
    lon = f->lon
  else
    lon = f->longitude
  end if
  if(range(2) .gt. range(3))
    printx("wrong range!")
    exit
  end if
  centerLon = where(min(lon)*max(lon) .ge. 0, 180, 0)
  range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
  range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
  if( (range(2) .ge. centerLon-180) .and. \
      (range(3) .le. centerLon+180));该情况不用分开读取
      var = f->$var_name$({range(0):range(1)},{range(2):range(3)})
  else
    adjust = where(range(2) .lt. centerLon-180,360,0)
    tem0 = f->$var_name$({range(0):range(1)},{range(2)+adjust:centerLon+180})
    tem1 = f->$var_name$({range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
    lon3 = concat([/lon-360,lon,lon+360/])
    lon3&lon = lon3
    lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
    var_lon = lon3(lon_ind)
    copy_VarAtts(lon,var_lon)
    var := merge([/tem0,tem1/],"lon",var_lon)
    dimsize = dimsizes(dimsizes(var))
    var := changeDimOrder(var,"lon",dimsize-1)
  end if
  return(var)
end

undef("read_from_file_CMIP6")
function read_from_file_CMIP6(file_path,type,var_name,range,res)
local year,isSingleFile,f,lon,utc_date,month,mon_ind,isFileLevel,isTypeLevel,isRangeLevel,centerLon,var,tem0,tem1,var_re,dim
begin

  isSingleFile = dimsizes(file_path) .eq. 1
  if(isSingleFile)
    f = addfile(file_path,"r")
    if(.not. isfilevar(f, var_name))
      printc("variable ("+var_name+") is not in file ("+file_path+")","red")
      printc("variables in this file:","red")
    end if
    isFileLevel = isfilevar(f,"level") .or. isfilevar(f,"lev")
    if(isfilevar(f,"lon"))
      lon = f->lon
    else
      lon = f->longitude
    end if
    ; utc_date = cd_calendar(f->time, 0)
    utc_date = cd_calendar_fix(f->time,0)
    ; printVarSummary(year)
    year     = floattointeger(utc_date(:,0))
    ; printVarSummary(year)
    month    = floattointeger(utc_date(:,1))
    if(type@year(0) .lt. year(0))
      printc("this data is available from "+(year(0)*100+month(0)),"red")
    end if
    mon_ind = ind_dev2(year,type@year,month,type@month)
    ; mon_ind = ind(year .ge. min(type@year) .and. year .le. max(type@year) .and. (month .ge. min(type@month) .and. month .le. max(type@month))) 
  else
  
    f = addfiles(file_path,"r")
    ListSetType(f,"cat")
    ; print(f[0])
    isFileLevel = isfilevar(f[0],"level") .or. isfilevar(f[0],"lev") .or. isfilevar(f[0],"plev")
    if(isfilevar(f[0],"lon")) 
      lon = f[0]->lon
    else
      lon = f[0]->longitude
    end if
  ; print(file_path)
  ; print(max(f[0]->time))
  ; print(min(f[1]->time))

    utc_date = cd_calendar_fix(f[:]->time,0)
    ; printVarSummary(year)
    year     = floattointeger(utc_date(:,0))
    ; printVarSummary(year)
    month    = floattointeger(utc_date(:,1))
    mon_ind = ind_dev2(year,type@year,month,type@month)
  end if
  
  if(range(2) .gt. range(3))
    printx("wrong range!")
    exit
  end if
  isTypeLevel = isatt(type,"level")
  isRangeLevel = dimsizes(type@range) .eq. 6
  if(isFileLevel)
    if(isRangeLevel)
      pres = file_path@pres
        pres!0 = "level"
        pres&level = pres
      minLev = min(range(4:))
      maxLev = max(range(4:))
      level := pres({minLev:maxLev})
    else if(isTypeLevel)
      level := type@level
    else
      printx("can not specify level(s)")
    end if
    end if
  end if
  centerLon = where(min(lon)*max(lon) .ge. 0, 180, 0)
  ; printx(centerLon)
  range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
  range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
  ; printx(range)
  if( (range(2) .ge. centerLon-180) .and. \
      (range(3) .le. centerLon+180));该情况不用分开读取
    if(isSingleFile)
      if(isFileLevel)
        var = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2):range(3)})
      else
        var = f->$var_name$(mon_ind,{range(0):range(1)},{range(2):range(3)})
      end if
    else
      if(isFileLevel)
        var = f[:]->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2):range(3)})
      else
        ; print(f[0])
        var = f[:]->$var_name$(mon_ind,{range(0):range(1)},{range(2):range(3)})
      end if
    end if
  else
    if(isSingleFile)
      adjust = where(range(2) .lt. centerLon-180,360,0)
      if(isFileLevel)
        tem0 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      else
        tem0 = f->$var_name$(mon_ind,{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f->$var_name$(mon_ind,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      end if
    else
      adjust = where(range(2) .lt. centerLon-180,360,0)
      if(isFileLevel)
        tem0 = f[:]->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f[:]->$var_name$(mon_ind,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      else
        tem0 = f[:]->$var_name$(mon_ind,{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f[:]->$var_name$(mon_ind,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      end if
    end if
    lon3 = concat([/lon-360,lon,lon+360/])
    renameDim([/lon3,tem0,tem1/],"longitude","lon")
    lon3&lon = lon3
    lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
    var_lon = lon3(lon_ind)
    copy_VarAtts(lon,var_lon)
    var := merge([/tem0,tem1/],"lon",var_lon)
    dimsize = dimsizes(dimsizes(var))
    var := changeDimOrder(var,"lon",dimsize-1)
    copy_VarAtts(tem0,var)
    copy_VarAtts(type,var)
    if(isatt(type,"pres")) delete(type@pres) end if
  end if
  ; delete(type@ind_year)
  renameDim(var,"latitude","lat")
  dim = dimsizes(var)
  printVarSummary(var)
  printVarSummary(type)
  var_re = reshape(var, (/dimsizes(type@year),dimsizes(type@month),dim(1),dim(2)/))
  copy_VarCoords(var(0,:,:), var_re(0,0,:,:))
  var_re!0="year"
  var_re!1="month"
  var_re&year = type@year
  var_re&month = type@month
  return(var_re)
end

; undef("read_from_range")
; function read_from_range(var,range)
; begin
;   isSingleFile = True
;   isFileLevel = False
;   range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
;   range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
;   ; printx(range)
;   if( (range(2) .ge. centerLon-180) .and. \
;       (range(3) .le. centerLon+180));该情况不用分开读取
;     if(isSingleFile)
;       if(isFileLevel)
;         var = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2):range(3)})
;       else
;         var = f->$var_name$(mon_ind,{range(0):range(1)},{range(2):range(3)})
;       end if
;     else
;       if(isFileLevel)
;         var = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{range(2):range(3)})
;       else
;         var = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{range(2):range(3)})
;       end if
;     end if
;   else
;     if(isSingleFile)
;       adjust = where(range(2) .lt. centerLon-180,360,0)
;       if(isFileLevel)
;         tem0 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
;         tem1 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
;       else
;         tem0 = f->$var_name$(mon_ind,{range(0):range(1)},{range(2)+adjust:centerLon+180})
;         tem1 = f->$var_name$(mon_ind,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
;       end if
;     else
;       adjust = where(range(2) .lt. centerLon-180,360,0)
;       if(isFileLevel)
;         tem0 = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
;         tem1 = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
;       else
;         tem0 = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{range(2)+adjust:centerLon+180})
;         tem1 = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
;       end if
;     end if
;     lon3 = concat([/lon-360,lon,lon+360/])
;     renameDim([/lon3,tem0,tem1/],"longitude","lon")
;     lon3&lon = lon3
;     lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
;     var_lon = lon3(lon_ind)
;     copy_VarAtts(lon,var_lon)
;     var := merge([/tem0,tem1/],"lon",var_lon)
;     dimsize = dimsizes(dimsizes(var))
;     var := changeDimOrder(var,"lon",dimsize-1)
;     copy_VarAtts(tem0,var)
;     copy_VarAtts(type,var)
;     if(isatt(type,"pres")) delete(type@pres) end if
;   end if
;   ; delete(type@ind_year)
;   renameDim(var,"latitude","lat")
;   return(var)
; end

undef("read_from_file")
function read_from_file(file_path,type)
local year,isSingleFile,f,lon,utc_date,month,mon_ind,isFileLevel,isTypeLevel,isRangeLevel,centerLon,var,tem0,tem1
begin
  range = type@range
  var_name = type
  isSingleFile = dimsizes(file_path) .eq. 1
  if(isSingleFile)
    f = addfile(file_path,"r")
    ; print(f)
    if(.not. isfilevar(f, var_name))
      printc("variable ("+var_name+") is not in file ("+file_path+")","red")
      printc("variables in this file:","red")
    end if
    ; print(f)
    isFileLevel = isfilevar(f,"level") .or. isfilevar(f,"lev")
    if(isfilevar(f,"lon"))
      lon = f->lon
    else
      lon = f->longitude
    end if
    ; utc_date = cd_calendar(f->time, 0)
    utc_date = cd_calendar_fix(f->time,0)
    ; printVarSummary(year)
    year     = floattointeger(utc_date(:,0))
    ; printVarSummary(year)
    month    = floattointeger(utc_date(:,1))
    ; print(month)
    if(type@year(0) .lt. year(0))
      printc("this data is available from "+(year(0)*100+month(0)),"red")
    end if
    mon_ind = ind_dev2(year,type@year,month,type@month)
    ; mon_ind = ind(year .ge. min(type@year) .and. year .le. max(type@year) .and. (month .ge. min(type@month) .and. month .le. max(type@month))) 
  else
    f = addfiles(file_path,"r")
    ListSetType(f,"join")
    isFileLevel = isfilevar(f[0],"level") .or. isfilevar(f[0],"lev")
    if(isfilevar(f[0],"lon")) 
      lon = f[0]->lon
    else
      lon = f[0]->longitude
    end if
  end if

  if(range(2) .gt. range(3))
    printx("wrong range!")
    exit
  end if
  isTypeLevel = isatt(type,"level")
  isRangeLevel = dimsizes(type@range) .eq. 6
  if(isFileLevel)
    if(isRangeLevel)
      pres = file_path@pres
        pres!0 = "level"
        pres&level = pres
      minLev = min(range(4:))
      maxLev = max(range(4:))
      level := pres({minLev:maxLev})
    elseif(isTypeLevel)
      level := type@level
    else
      printx("can not specify level(s)")
    end if
  end if
  centerLon = where(min(lon)*max(lon) .ge. 0, 180, 0)
  ; printx(centerLon)
  range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
  range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
  ; printx(range)
  if( (range(2) .ge. centerLon-180) .and. \
      (range(3) .le. centerLon+180));该情况不用分开读取
    if(isSingleFile)
      if(isFileLevel)
        var = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2):range(3)})
      else
        var = f->$var_name$(mon_ind,{range(0):range(1)},{range(2):range(3)})
      end if
    else
      if(isFileLevel)
        var = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{range(2):range(3)})
      else
        var = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{range(2):range(3)})
      end if
    end if
  else
    if(isSingleFile)
      adjust = where(range(2) .lt. centerLon-180,360,0)
      if(isFileLevel)
        tem0 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      else
        tem0 = f->$var_name$(mon_ind,{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f->$var_name$(mon_ind,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      end if
    else
      adjust = where(range(2) .lt. centerLon-180,360,0)
      if(isFileLevel)
        tem0 = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      else
        tem0 = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      end if
    end if
    lon3 = concat([/lon-360,lon,lon+360/])
    renameDim([/lon3,tem0,tem1/],"longitude","lon")
    lon3&lon = lon3
    lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
    var_lon = lon3(lon_ind)
    copy_VarAtts(lon,var_lon)
    var := merge([/tem0,tem1/],"lon",var_lon)
    dimsize = dimsizes(dimsizes(var))
    var := changeDimOrder(var,"lon",dimsize-1)
    copy_VarAtts(tem0,var)
    copy_VarAtts(type,var)
    if(isatt(type,"pres")) delete(type@pres) end if
  end if
  ; delete(type@ind_year)
  renameDim(var,"latitude","lat")
  return(var)
end


undef("read_from_file_dev")
function read_from_file_dev(file_path,type,var_name,range,res)
local year,isSingleFile,f,lon,utc_date,month,mon_ind,isFileLevel,isTypeLevel,isRangeLevel,centerLon,var,tem0,tem1,dim_level,isSingleLevel,level
begin
  isSingleFile = dimsizes(file_path) .eq. 1
  isSingleLevel = False
  if(isSingleFile)
    f = addfile(file_path,"r")
    if(.not. isfilevar(f, var_name))
      printc("variable ("+var_name+") is not in file ("+file_path+")","red")
      printc("variables in this file:","red")
    end if
    ; print(f)
    isFileLevel = isfilevar(f,"level") .or. isfilevar(f,"lev")
    if(isFileLevel)
      if(isfilevar(f,"level"))then
        dim_level = dimsizes(f->level)
        isSingleLevel = (dim_level .eq. 1)
        level = f->level
      end if
      if(isfilevar(f,"lev"))then
        dim_level = dimsizes(f->lev)
        isSingleLevel = (dim_level .eq. 1)
        level = f->lev
      end if
    end if
    if(isfilevar(f,"lon"))
      lon = f->lon
    else
      lon = f->longitude
    end if
    ; utc_date = cd_calendar(f->time, 0)
    utc_date = cd_calendar_fix(f->time,0)
    ; printVarSummary(year)
    year     = floattointeger(utc_date(:,0))
    ; printVarSummary(year)
    month    = floattointeger(utc_date(:,1))
    if(type@year(0) .lt. year(0))
      printc("this data is available from "+(year(0)*100+month(0)),"red")
    end if
    mon_ind = ind_dev2(year,type@year,month,type@month)
    ; mon_ind = ind(year .ge. min(type@year) .and. year .le. max(type@year) .and. (month .ge. min(type@month) .and. month .le. max(type@month))) 
  else
    f = addfiles(file_path,"r")
    ListSetType(f,"join")
    isFileLevel = isfilevar(f[0],"level") .or. isfilevar(f[0],"lev")
    if(isFileLevel)
      if(isfilevar(f[0],"level"))then
        dim_level = dimsizes(f[0]->level)
        isSingleLevel = (dim_level .eq. 1)
        level = f[0]->level
      end if
      if(isfilevar(f[0],"lev"))then
        dim_level = dimsizes(f[0]->lev)
        isSingleLevel = (dim_level .eq. 1)
        level = f[0]->lev
      end if
    end if
    if(isfilevar(f[0],"lon")) 
      lon = f[0]->lon
    else
      lon = f[0]->longitude
    end if
  end if

  if(range(2) .gt. range(3))
    printx("wrong range!")
    exit
  end if
  isTypeLevel = isatt(type,"level")
  isRangeLevel = dimsizes(type@range) .eq. 6
  if(isFileLevel .and. .not. isSingleLevel)
    if(isRangeLevel)
      pres = file_path@pres
        pres!0 = "level"
        pres&level = pres
      minLev = min(range(4:))
      maxLev = max(range(4:))
      level := pres({minLev:maxLev})
    elseif(isTypeLevel)
      level := type@level
    else
      printx("can not specify level(s)")
    end if
  end if
  centerLon = where(min(lon)*max(lon) .ge. 0, 180, 0)
  ; printx(centerLon)
  range(2:) = range(2:)-where(range(2) .ge. centerLon+180,360,0)
  range(2:) = range(2:)+where(range(3) .le. centerLon-180,360,0)
  ; printx(range)
  if( (range(2) .ge. centerLon-180) .and. \
      (range(3) .le. centerLon+180));该情况不用分开读取
    if(isSingleFile)
      if(isFileLevel)
        var = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2):range(3)})
      else
        var = f->$var_name$(mon_ind,{range(0):range(1)},{range(2):range(3)})
      end if
    else
      if(isFileLevel)
        var = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{range(2):range(3)})
      else
        var = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{range(2):range(3)})
      end if
    end if
  else
    if(isSingleFile)
      adjust = where(range(2) .lt. centerLon-180,360,0)
      if(isFileLevel)
        tem0 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f->$var_name$(mon_ind,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      else
        tem0 = f->$var_name$(mon_ind,{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f->$var_name$(mon_ind,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      end if
    else
      adjust = where(range(2) .lt. centerLon-180,360,0)
      if(isFileLevel)
        tem0 = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f[:]->$var_name$(:,type@month-1,{level},{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      else
        tem0 = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{range(2)+adjust:centerLon+180})
        tem1 = f[:]->$var_name$(:,type@month-1,{range(0):range(1)},{centerLon-180:range(3)-(360-adjust)})
      end if
    end if
    lon3 = concat([/lon-360,lon,lon+360/])
    renameDim([/lon3,tem0,tem1/],"longitude","lon")
    lon3&lon = lon3
    lon_ind = ind(lon3 .ge. range(2) .and. lon3 .le. range(3))
    var_lon = lon3(lon_ind)
    copy_VarAtts(lon,var_lon)
    var := merge([/tem0,tem1/],"lon",var_lon)
    dimsize = dimsizes(dimsizes(var))
    var := changeDimOrder(var,"lon",dimsize-1)
    copy_VarAtts(tem0,var)
    copy_VarAtts(type,var)
    if(isatt(type,"pres")) delete(type@pres) end if
  end if
  ; delete(type@ind_year)
  renameDim(var,"latitude","lat")
  return(var)
end

undef("read_from_config")
function read_from_config (tp,opt)
local type,month,f,type_neg,var,month_pos,month_neg,type_pos,type_neg,var_pos,var_neg,tem_pos,tem_neg,att_tem,tem,dimNames,ind_year,ind_month,ind_lev,level,nYear,nMon,nTime,dim_to_conform,i
begin
  type = tp
  month    = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
  f = read_var_path(type)
  var = read_from_file_dev(f,type,type@var,type@range,opt) 
  ; printVarSummary(var)
  tem = type
  delete(tem@year)
  copy_VarAtts(tem, var)
  dimNames = getvardims(var)
  var@month := get_month(type@month)
  var@name = type@var
  delete(type@var)
  if( .not. isArray(type@year) .and. .not. isArray(type@month))
    return var
  end if
  if(isdim(var,"ncl_join"))
    ind_year = ind(dimNames .eq. "ncl_join")
    var!ind_year = "year"
    var&year = type@year
    var := changeDimOrder(var,"year",0)
  end if
  renameDim(var,"longitude","lon")
  if(isdim(var,"lev"))
    ind_lev = ind(dimNames .eq. "lev")
    var!ind_lev = "level"
    dimNames(ind_lev) = "level"
  end if
  if(isdim(var,"level"))
    level = var&level
    level@units = "hPa"
    level@standard_name = "air_pressure"
    level@long_name = "vertical level"
    level@positive = "down"
    level@axis = "Z"
    var&level = level
  end if
  nYear = dimsizes(type@year)
  nMon = dimsizes(type@month)
  dimNames = getvardims(var)
  if(isdim(var,"time"))
    nTime = dimsizes(var&time)
    if(nTime .eq. nMon)
      ind_month = ind(dimNames .eq. "time")
      var!ind_month = "month"
      var&month = type@month
      return(var)
    end if
    if(nTime .eq. nMon*nYear)
      if(nMon .eq. 1)
        ind_year = ind(dimNames .eq. "time")
        var!ind_year = "year"
        var&year = type@year
      else
        tem := var
        dim = dimsizes(var)
        dim_to_conform = new(dimsizes(dim)+1,integer)
        dim_to_conform(0:1) = (/nYear,dim(0)/nYear/)
        dim_to_conform(2:) = dim(1:)
        var := reshape(tem,dim_to_conform)
        var!0 = "year"
        var!1 = "month"
        var&month = type@month
        var&year = type@year
        do i = 2, dimsizes(dimNames)
          var!i = dimNames(i-1)
          var&$dimNames(i-1)$ = tem&$dimNames(i-1)$
        end do
        copy_VarAtts(tem,var)
      end if
      return(var)
    end if
  end if
  var := changeDimOrder(var,"year",0)
  return(var)
  ; var@mon_name = ""
  ; do i = min(var&month),max(var&month),1
  ;   tem := str_split_by_length(month(i-1),1)
  ;   var@mon_name = var@mon_name+tem(0)
  ; end do  
end

undef("getValueWithKey")
function getValueWithKey(var,seperator,key[*])
local seper_ind,seper_list,loc,isLast,line
begin
  seper_ind = str_match_ind(var, seperator)
  seper_list = var(seper_ind)
  loc = str_match_ind(seper_list, str_upper(" "+key+","))
  if(ismissing(loc))
    printc(key+" is not found","red")
  end if
  isLast = loc .eq. dimsizes(seper_list)-1
  line = seper_ind(loc)
  if(isLast)
    return var(line:)
  else
    return var(line:seper_ind(loc+1)-1)
  end if
end

undef("readCMIP6Path")
function readCMIP6Path(var)
local test,tem,path,line,type,varPath,varName,scenario,dimScenario,value
begin
  test = asciiread(localpath(3)+"config_CMIP6.txt", -1, "string")
  tem = getValueWithKey(test,"Source:",var@source)
  path = str_split(str_match(tem, "Path"), ": ")
  type = var
  if(min(type@year) .ge. 2015)then
    scenario = "ssp585"
  elseif(max(type@year) .le. 2014)then
    scenario = "historical"
  else
    scenario = (/"historical","ssp585","ssp585_alt"/)
  end if
  dimScenario = dimsizes(scenario)
  if(dimScenario .eq. 1)
    value := getValueWithKey(tem,"Scenario:",scenario)
    ; print(str_match(value, str_upper(var)))
    line = str_split(str_match(value,str_upper(var)), " ")
    type@varName = line(2)
    type@varPath = localpath(0)+path(1)+var@model+"/"+line(3)
    return type
  else
    varName = new(2,string)
    varPath = new(2,string)
    value := getValueWithKey(tem,"Scenario:",scenario(0))
    line := str_split(str_match(value(1:),str_upper(var)), " ")
    varName(0) = line(2)
    varPath(0) = localpath(0)+path(1)+var@model+"/"+line(3)
    value := getValueWithKey(tem,"Scenario:",scenario(1))
    line := str_split(str_match(value,str_upper(var)), " ")
    varName(1) = line(2)
    varPath(1) = localpath(0)+path(1)+var@model+"/"+line(3)
    ; print(varPath)
    if( .not. fileexists(varPath(1)))then
      ; print(line)
      value := getValueWithKey(tem,"Scenario:",scenario(2))
      line := str_split(str_match(value,str_upper(var)), " ")
      ; print(line)
      varName(1) = line(2)
      varPath(1) = localpath(0)+path(1)+var@model+"/"+line(3)
    end if
    type@varName = varName
    type@varPath = varPath
    return type
  end if
end

undef("readCMIP6")
function readCMIP6(type,opt)
local tp,dimPath,ls,tem0,tem1,var,nYear,nMon,dimVar,dimNames,nTime,ind_month,ind_year,dim,dim_to_conform,i
begin
  tp = readCMIP6Path(type)
  dimPath = dimsizes(tp@varPath)
  ; var = read_from_file_CMIP6(tp@varPath,tp,tp@varName,tp@range,True)
  if(all(type@month .lt. 0))
    type_neg = type
    type_neg@month = type@month*-1
    type_neg@year = type@year-1
    var = read_from_file_CMIP6(tp@varPath,tp,tp@varName,tp@range,True)
  elseif(any(type@month .lt. 0))
    month_pos = type@month(ind(type@month .gt. 0))
    month_neg = type@month(ind(type@month .lt. 0))
    type_pos = type
      type_pos@month := month_pos
    type_neg = type
      type_neg@month := month_neg*-1
    var_pos = read_from_file_CMIP6(tp@varPath,type_pos,tp@varName,tp@range,True)
    var_neg = read_from_file_CMIP6(tp@varPath,type_neg,tp@varName,tp@range,True)
    tem := merge([/var_neg,var_pos/],"month",type@month)
    var = changeDimOrder(tem,"year",0)
    copy_VarAtts(var_pos,var)
  else
    var = read_from_file_CMIP6(tp@varPath,tp,tp@varName,tp@range,True) 
  end if
  nYear = dimsizes(type@year)
  nMon = dimsizes(type@month)
  dimVar = dimsizes(var)
  dimNames = getvardims(var)
  var@source = type@source
  var@month = type@month
  if(isdim(var,"time"))
    nTime = dimVar(0)
    if(nTime .eq. nMon)
      ind_month = ind(dimNames .eq. "time")
      var!ind_month = "month"
      var&month = type@month
      return(var)
    end if
    if(nTime .eq. nMon*nYear)
      if(nMon .eq. 1)
        ind_year = ind(dimNames .eq. "time")
        var!ind_year = "year"
        var&year = type@year
      else
        tem = var
        dim = dimsizes(var)
        dim_to_conform = new(dimsizes(dim)+1,integer)
        dim_to_conform(0:1) = (/nYear,dim(0)/nYear/)
        dim_to_conform(2:) = dim(1:)
        var := reshape(tem,dim_to_conform)
        var!0 = "year"
        var!1 = "month"
        var&month = type@month
        var&year = type@year
        do i = 2, dimsizes(dimNames)
          var!i = dimNames(i-1)
          var&$dimNames(i-1)$ = tem&$dimNames(i-1)$
        end do
        copy_VarAtts(tem,var)
      end if
    end if
  end if
  return(var)
end

undef("readCESM2LEPath")
function readCESM2LEPath(var)
local test,tem,path,line,type
begin
  test = asciiread(localpath(3)+"config_CESM2LE.txt", -1, "string")
  tem = getValueWithKey(test,"Source:",var@source)
  path = str_split(str_match(tem, "Path"), ": ")
  type = var
  if(min(type@year) .ge. 2015)then
    scenario = "ssp370"
  elseif(max(type@year) .le. 2014)then
    scenario = "historical"
  else
    scenario = (/"historical","ssp370"/)
  end if
  dimScenario = dimsizes(scenario)
  if(dimScenario .eq. 1)
    value := getValueWithKey(tem,"Scenario:",scenario)
    ; print(str_match(value, str_upper(var)))
    line = str_split(str_match(value,str_upper(var)), " ")
    type@varName = line(2)
    type@varPath = localpath(0)+path(1)+scenario+"/"+str_upper(var)+"/"+str_upper(var)+".regrid."+var@member+line(3)
    ; print(type@varPath)
    return type
  else
    varName = new(2,string)
    varPath = new(2,string)
    value := getValueWithKey(tem,"Scenario:",scenario(0))
    line := str_split(str_match(value(1:),str_upper(var)), " ")
    varName(0) = line(2)
    varPath(0) = localpath(0)+path(1)+scenario(0)+"/"+str_upper(var)+"/"+str_upper(var)+".regrid."+var@member+line(3)
    value := getValueWithKey(tem,"Scenario:",scenario(1))
    line := str_split(str_match(value,str_upper(var)), " ")
    varName(1) = line(2)
    varPath(1) = localpath(0)+path(1)+scenario(1)+"/"+str_upper(var)+"/"+str_upper(var)+".regrid."+var@member+line(3)
    type@varName = varName
    type@varPath = varPath
    return type
  end if
end

undef("readCESM2LE")
function readCESM2LE(type,opt)
local tp,dimPath,ls,tem0,tem1,var,nYear,nMon,dimVar,dimNames,nTime,ind_month,ind_year,dim,dim_to_conform,i
begin
  tp = readCESM2LEPath(type)
  dimPath = dimsizes(tp@varPath)
  ; var = read_from_file_CMIP6(tp@varPath,tp,tp@varName,tp@range,True)
  if(all(type@month .lt. 0))
    type_neg = type
    type_neg@month = type@month*-1
    type_neg@year = type@year-1
    var = read_from_file_CMIP6(tp@varPath,tp,tp@varName,tp@range,True)
  elseif(any(type@month .lt. 0))
    month_pos = type@month(ind(type@month .gt. 0))
    month_neg = type@month(ind(type@month .lt. 0))
    type_pos = type
      type_pos@month := month_pos
    type_neg = type
      type_neg@month := month_neg*-1
    var_pos = read_from_file_CMIP6(tp@varPath,type_pos,tp@varName,tp@range,True)
    var_neg = read_from_file_CMIP6(tp@varPath,type_neg,tp@varName,tp@range,True)
    tem := merge([/var_neg,var_pos/],"month",type@month)
    var = changeDimOrder(tem,"year",0)
    copy_VarAtts(var_pos,var)
  else
    var = read_from_file_CMIP6(tp@varPath,tp,tp@varName,tp@range,True) 
  end if
  nYear = dimsizes(type@year)
  nMon = dimsizes(type@month)
  dimVar = dimsizes(var)
  dimNames = getvardims(var)
  var@source = type@source
  var@month = type@month
  if(isdim(var,"time"))
    nTime = dimVar(0)
    if(nTime .eq. nMon)
      ind_month = ind(dimNames .eq. "time")
      var!ind_month = "month"
      var&month = type@month
      return(var)
    end if
    if(nTime .eq. nMon*nYear)
      if(nMon .eq. 1)
        ind_year = ind(dimNames .eq. "time")
        var!ind_year = "year"
        var&year = type@year
      else
        tem = var
        dim = dimsizes(var)
        dim_to_conform = new(dimsizes(dim)+1,integer)
        dim_to_conform(0:1) = (/nYear,dim(0)/nYear/)
        dim_to_conform(2:) = dim(1:)
        var := reshape(tem,dim_to_conform)
        var!0 = "year"
        var!1 = "month"
        var&month = type@month
        var&year = type@year
        do i = 2, dimsizes(dimNames)
          var!i = dimNames(i-1)
          var&$dimNames(i-1)$ = tem&$dimNames(i-1)$
        end do
        copy_VarAtts(tem,var)
      end if
    end if
  end if
  return(var)
end

undef("readReanalysis")
function readReanalysis(type,opt)
local tp,dimPath,ls,tem0,tem1,var,nYear,nMon,dimVar,dimNames,nTime,ind_month,ind_year,dim,dim_to_conform,i,month
begin
  if(isatt(type, "polyLon") .and. isatt(type, "polyLat"))then
    type@range := (/min(type@polyLat),max(type@polyLat),min(type@polyLon),max(type@polyLon)/)
  end if
  month    = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
  if(all(type@month .lt. 0))
    type_neg = type
    type_neg@month = type@month*-1
    type_neg@year = type@year-1
    var = read_from_config(type_neg,opt)
  elseif(any(type@month .lt. 0))
    month_pos = type@month(ind(type@month .gt. 0))
    month_neg = type@month(ind(type@month .lt. 0))
    type_pos = type
      type_pos@month := month_pos
    type_neg = type
      type_neg@month := month_neg*-1
      type_neg@year = type@year-1
    var_pos = read_from_config(type_pos,opt)
    var_neg = read_from_config(type_neg,opt)
    var := merge([/var_neg,var_pos/],"month",type@month)
    var := changeDimOrder(var,"year",0)
    copy_VarAtts(var_pos,var)
  else
    var = read_from_config(type,opt) 
  end if
  if(isatt(type, "polyLon") .and. isatt(type, "polyLat"))then
    var = extract(var,type@polyLon,type@polyLat)
  end if
  ; printVarSummary(var)
  return(var)
end