begin ;记录全局参数
  ; start_time = get_cpu_time()
  pwd = systemfunc("pwd")
  if(isStrSubset(pwd,"/Users/linlifei/code/"))
    localpath = (/"/Volumes/Libra/","/Users/linlifei/","/Volumes/Libra/","/Users/linlifei/code/ncl/"/)
    loadPath = "/Users/linlifei/code/ncl/ncl_lib/"
  elseif(isStrSubset(pwd,"/home/ys17-23/LLF/code/"))
    localpath := (/"/home/ys17-23/Extension2/llf/","/home/ys17-23/Extension2/llf/","/home/ys17-23/Extension2/llf/","/home/ys17-23/LLF/code/ncl/"/)
    loadPath = "/home/ys17-23/LLF/code/ncl/ncl_lib/"
  elseif(isStrSubset(pwd,"/home/llf/code/"))
    localpath := (/"/data/","/data/","/data/","/home/llf/code/ncl/"/)
    loadPath = "/home/llf/code/ncl/ncl_lib/"
  end if
  call_stream = NewList("fifo")
  bufferPath = localpath(1)+"buffer/"
  bufferMode = "disabled"
  bufferIdList = NewList("fifo")
  bufferFileList = NewList("fifo")
  bufferCount = 0
  ; localpath = (/"/mnt/c/data/","/mnt/c/data/","/mnt/c/data/"/)
  clr = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  script = get_script_prefix_name()
  except = (/"_FillValue","mode","time","tval","nptxy","rstd","yintercept","forecast_time","initial_time","average_op_ncl","sub_center","level_indicator","gds_grid_type","parameter_table_version","parameter_number","forecast_time_units","statistical_process_descriptor","statistical_process_duration"/)
  res_plot = (/"am","cn","gs","gsn","lb","lg","mp","pm","pr","sf","tf","ti","tm","tr","tx","vc","vf","vp","wk","ws","xy","Scale"/)
  global = (/-90,90,0,360/)
  NH = (/0,90,0,360/)
  NH_ex = (/20,90,0,360/)
  SH = (/-90,0,0,360/)
  levels       := (/1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100/)
end

load "sub_toolbox.ncl"
load "sub_read.ncl"
load "sub_calc.ncl"
load "sub_plot.ncl"
load "fixBarColor.ncl"

undef("show")
procedure show(fileName[1])
local type
begin
  if(typeof(fileName) .eq. "string")then
    print("showImage: "+fileName)
  elseif(NhlIsWorkstation(fileName))then
    if(isatt(fileName, "path"))
      print("showImage: "+fileName@path)
    end if
  end if
end

;函数定义
undef("getJetAxisStrength")
function getJetAxisStrength(U)
local lat, ind_lon,jet_lat,jet_strength,jet_strength_lon
begin
  lat = U&lat
  jet_strength_lon = dim_max_n_Wrap(U, 0)
  jet_strength = dim_avg_Wrap(jet_strength_lon)
  return jet_strength
end
undef("calcJetAxisStrength")
function calcJetAxisStrength(uwnd)
local dims,dimNames,timeInd,timeLength,jetLats,jetStrength,tem
begin
  dims = dimsizes(uwnd)
  dimNames = getvardims(uwnd)
  timeInd = ind(dimNames .eq. "year")
  timeLength = dims(timeInd)
  jetLats = new(timeLength, float)
  jetStrength = new(timeLength, float)
  do i = 0, timeLength-1
    ; jetLats(i) = getJetLat(uwnd(i,:,:))
    ; jetStrength(i) = dim_avg_n_Wrap(uwnd(i,{jetLats(i)-4:jetLats(i)+4},:), (/0,1/))
    jetStrength(i) = (/getJetAxisStrength(uwnd(i,:,:))/)
    ; jetStrength(i) = (/0/)
  end do
  copy_VarCoords(uwnd(:,0,0), jetStrength)
  return jetStrength
end

undef("calcRunCorEAJWAJ")
function calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
local tp,U200,EAJ_index,WAJ_index,cor,method
begin
  method = "mean"
  tp = type
    tp@range := rangeEAJ
  U200 := process(tp,method)
  EAJ_index := calcJetAxisStrength(U200)
    tp@range := rangeWAJ
  U200 := process(tp,method)
  WAJ_index := calcJetAxisStrength(U200)
  cor := run_cor(WAJ_index, EAJ_index, window)
  return cor
end

undef("calcJetLatitudeByAxis")
function calcJetLatitudeByAxis(uwnd)
local dims,dimNames,timeInd,timeLength,jetLats,tem
begin
  dims = dimsizes(uwnd)
  dimNames = getvardims(uwnd)
  timeInd = ind(dimNames .eq. "year")
  timeLength = dims(timeInd)
  jetLats = new(timeLength, float)
  ; printVarSummary(uwnd)
  do i = 0, timeLength-1
    tem := getJetLat(uwnd(i,:,:))
    jetLats(i) = getJetLat(uwnd(i,:,:))
  end do
  copy_VarCoords(uwnd(:,0,0), jetLats)
  return jetLats
end

undef("calcJetStrengthByAxis")
function calcJetStrengthByAxis(uwnd)
local dims,dimNames,timeInd,timeLength,jetLats,jetStrength,tem
begin
  dims = dimsizes(uwnd)
  dimNames = getvardims(uwnd)
  timeInd = ind(dimNames .eq. "year")
  timeLength = dims(timeInd)
  jetLats = new(timeLength, float)
  jetStrength = new(timeLength, float)
  do i = 0, timeLength-1
    tem := getJetLat(uwnd(i,:,:))
    jetLats(i) = getJetLat(uwnd(i,:,:))
    jetStrength(i) = dim_avg_n_Wrap(uwnd(i,{jetLats(i)-4:jetLats(i)+4},:), (/0,1/))
  end do
  copy_VarCoords(uwnd(:,0,0), jetStrength)
  return jetStrength
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

undef("addShading")
procedure addShading(plotid,upper,lower,opt)
local tem_wks,xArray,yArray,rpoly,str
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  xArray = array_append_record(upper&year, lower&year(::-1), 0)
  yArray = array_append_record(upper, lower(::-1), 0)
  rpoly := True
    rpoly@gsFillColor = get_res_value_keep(opt, "gsFillColor", "Tomato")
    rpoly@gsFillOpacityF = get_res_value_keep(opt, "gsFillOpacityF", 0.1)
    rpoly@tfPolyDrawOrder = "PreDraw"
  str = unique_string("shading")
  plotid@$str$ = gsn_add_polygon(tem_wks, plotid, xArray, yArray, rpoly)
end

undef("addSpreading")
procedure addSpreading(plotid,data,opt)
local tem_wks,data_mean,data_std,upper,lower
begin
  data_mean = dim_avg_n_Wrap(data, 0)
  data_std = dim_stddev_n_Wrap(data, 0)
  upper = data_mean+0.5*data_std
  lower = data_mean-0.5*data_std
  copy_VarCoords(data_mean, upper)
  copy_VarCoords(data_mean, lower)
  addShading(plotid,upper,lower,opt)
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

undef("newFilledTriangle")
function newFilledTriangle(wks)
local mstring,fontnum,xoffset,ratio,size,angle,new_index
begin
  mstring = "u"
  fontnum = 34
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 1.2
  size    := 1.5
  angle   = 0.0
  new_index = NhlNewMarker(wks,mstring,fontnum,xoffset,yoffset,ratio,size,angle)
  return new_index
end

undef("newFilledSquare")
function newFilledSquare(wks)
local mstring,fontnum,xoffset,ratio,size,angle,new_index
begin
mstring = "y"
  fontnum = 35
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 1.0
  size    = 1.0
  angle   = 0.0
  new_index = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, ratio, size, angle)
  return new_index
end


undef("newFilledPentagram")
function newFilledPentagram(wks)
local mstring,fontnum,xoffset,ratio,size,angle,new_index
begin
mstring = "z"
  fontnum = 35
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 1.0
  size    = 1.0
  angle   = 0.0
  new_index = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, ratio, size, angle)
  return new_index
end

undef("newHollowCross")
function newHollowCross(wks)
local mstring,fontnum,xoffset,ratio,size,angle,new_index
begin
mstring = "+"
  fontnum = 121
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 1.0
  size    = 1.5
  angle   = 0.0
  new_index = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, ratio, size, angle)
  return new_index
end
begin
  ;部分参数
  folder = localpath(3)+"EurasianJet/Eurasian_figs/" ;"EAJ_plot"
  setBufferPath(localpath(3)+".buffer/")
  bufferMode = "disabled"
  ; bufferMode = "smart"
  fig = "pdf"
    fig@wkPaperWidthF = 20
    fig@wkPaperHeightF = 20
  png = "png"
    png@wkHeight = 2000
    png@wkWidth = 2000
  year := ispan(1958, 2022, 1)
  year0 := ispan(1958, 1978, 1)
  year1 := ispan(1979, 1998, 1)
  year2 := ispan(1999, 2022, 1)
  month = (/7,8/)
  rangeWAJ = (/40, 47, 45, 85/)
  rangeEAJ = (/40, 47, 90, 130/)
  setDim(year,0,"year",year)
  setDim(year0,0,"year",year0)
  setDim(year1,0,"year",year1)
  WNPSH_level = 5870
  SAH_level = 14360
;# ESWJ指数(急流轴强度)
window = 21
rangeWAJ := (/20, 70, 40, 80./)
rangeEAJ := (/20, 70, 90, 123./)
type := "u"
  type@source = "ERA5"
  type@month := (/7,8/)
  type@year := ispan(1940, 2022, 1)
  type@level = 200
  type@range = (/10,80,-12.5,191/)
method := "stddev"
  method@detrend = False
  type@range = (/20,60,30,155/)
U200_sd := process(type,method)
method := "mean"
  method@detrend = False
  type@range := (/20, 70, 23, 123./)
  type@year := year
U200 := process(type,method)
ESWJ := calcJetAxisStrength(U200)
ESWJ0 := dim_standardize_Wrap(ESWJ({year0}), 0)
ESWJ1 := dim_standardize_Wrap(ESWJ({year1}), 0)
ESWJ2 := dim_standardize_Wrap(ESWJ({year2}), 0)
print(ESWJ)
  type@range = rangeWAJ
U200 := process(type,method)
WAJ_index := calcJetAxisStrength(U200)
  type@range = rangeEAJ
U200 := process(type,method)
EAJ_index := calcJetAxisStrength(U200)

;# 急流轴计算
type := "u"
  type@source = "ERA5"
  type@range = (/20,60,15,160/)
  type@year := ispan(1958, 2022, 1)
  type@level = 200
;   type@month = 4
method = "clim"
  type@month = 5
U200_clim := process(type,method)
lat_May := getJetLats(U200_clim)
lat_May := runave_Wrap(lat_May, 7, 0)
  type@month = 6
U200_clim := process(type,method)
lat_June := getJetLats(U200_clim)
lat_June := runave_Wrap(lat_June, 6, 0)
  type@month := (/5,6/)
U200_clim := process(type,method)
lat_MJ := getJetLats(U200_clim)
lat_MJ := runave_Wrap(lat_MJ, 7, 0)
  type@month := (/7,8/)
U200_clim := process(type,method)
lat_JA := getJetLats(U200_clim)
lat_JA := runave_Wrap(lat_JA, 7, 0)

;# EOF计算
; year0 := ispan(1958, 1978, 1)
; year1 := ispan(1979, 1998, 1)
; year2 := ispan(1999, 2022, 1)
opt := True
type = "u"
  type@level = 200
  ; type@year := ispan(1999,2018,1)
  type@year := year0
  ; type@year := ispan(1999,2018,1)
  type@month := (/7,8/)
  type@source = "ERA5"
  ; type@range = (/20,65,30,150/)
  type@range = (/20,65,20,150/)
  ; range = (/20,55,80,130/)
; range = (/20,60,80,130/)
method = "anom"
  method@detrend = False
; print(opt)
X := process(type,opt)
    opt@neof = 3
    opt@jopt = 0
    opt@weight = True
    opt@reof = False
    opt@rev := (/-1, -1,1/)
    opt@name = "EAJ"
    opt@lbOrientation = "Vertical"
    opt@xcnLevels = (/-4,-3,-2,-1,1,2,3,4/)
    opt@minmax = (/-3,3/)
EAJ0 := EOF(X,opt)
    EAJ0@units = ""
    pcvar0 := EAJ0@pcvar

    opt@rev = (/1, -1,-1/)
    type@year := year1
X := process(type,opt)
EAJ1 := EOF(X,opt)
    EAJ1@units = ""
    pcvar1 := EAJ1@pcvar
    opt@rev = (/1, -1,1/)
    type@year := year2
X := process(type,opt)
EAJ2 := EOF(X,opt)
    EAJ1@units = ""
    pcvar2 := EAJ2@pcvar
EOF_p0 := EAJ0(0,:)
EOF_p1 := EAJ1(0,:)  
EOF_p2 := EAJ2(0,:)  
;# EOF1
ts0 := EAJ0(0,:)
ts1 := EAJ1(0,:)  
ts2 := EAJ2(0,:)  

;TPH和WNPSH合成
;计算
ts1 := ESWJ2
  ind_h1 := ind(ts1 .ge.  0.5)
  ind_l1 := ind(ts1 .le. -0.5)
print(ESWJ2)
print(year2(ind_h1))
print(year2(ind_l1))
; print(ind_l1)
opt = True
ranges := (/10,50,10,120/)
range := (/0,50,100,190/)
type := "H"
type@level := 150
type@month := (/7,8/)
type@source = "era5"
type@range = ranges
opt@method = "clim"
type@year := year2
SAH_clim1 := process(type,opt)

type@level = 500
type@range = (/10,50,100,190/)
type@year = year2
WNPSH_clim1 = process(type,opt)

type_h := "H"
type_h@range = range
type_h@level = 500
type_h@month = (/7,8/)
type_h@source = type@source
type_h@year := ts1&year(ind_h1)
WPSH_h := process(type_h,opt)

type_l = "H"
type_l@range = range
type_l@level = 500
type_l@month = (/7,8/)
type_l@source = type@source
type_l@year := ts1&year(ind_l1)
WPSH_l := process(type_l,opt) 

type_h@level = 150
type_h@range = (/00,80,20,130/)
type_h@year := ts1&year(ind_h1)
SAH_h := process(type_h,opt)

type_l@level = 150
type_l@range = (/00,80,20,130/)
type_l@year := ts1&year(ind_l1)
SAH_l := process(type_l,opt)

;# 各套数据的急流轴强度指数及滑动相关
window = 21
rangeWAJ := (/20, 70, 40, 80./)
rangeEAJ := (/20, 70, 90, 123./)
type := "u"
  type@source = "era5"
  type@month := (/7,8/)
  type@year := ispan(1940, 2022, 1)
  type@level = 200
  type@range := rangeEAJ
method := "mean"
cor_ERA5 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "ncep2"
  type@year := ispan(1979, 2022, 1)
cor_ncep2 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "ncep1"
  type@year := ispan(1958, 2022, 1)
cor_ncep1 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "era-i"
  type@year := ispan(1979, 2018, 1)
cor_erai := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "jra55"
  type@year := ispan(1958, 2022, 1)
cor_jra55 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "CFS"
  type@year := ispan(1979, 2022, 1)
cor_cfs := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "20thCRV3"
  type@year := ispan(1836, 2015, 1)
cor_20th := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

  type@source = "ERA-20C"
  type@year := ispan(1901, 2010, 1)
cor_era20c := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
  type@source = "ERA-20CM"
  type@year := ispan(1900, 2010, 1)
cor_era20cm := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)

type = "u1"
  type@source = "CERA-20C"
  type@year := ispan(1901, 2010, 1)
cor_cera20c1 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u2"
cor_cera20c2 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u3"
cor_cera20c3 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u4"
cor_cera20c4 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u4"
cor_cera20c4 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u4"
cor_cera20c4 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u5"
cor_cera20c5 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u6"
cor_cera20c6 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u7"
cor_cera20c7 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u8"
cor_cera20c8 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u9"
cor_cera20c9 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
type = "u10"
cor_cera20c10 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
cor_cera20c := (/cor_cera20c1,cor_cera20c2,cor_cera20c3,cor_cera20c4,cor_cera20c5,cor_cera20c6,cor_cera20c7,cor_cera20c8,cor_cera20c9,cor_cera20c10/)
copy_VarCoords(cor_cera20c1, cor_cera20c(0,:))
cor_cera20c_mean = dim_avg_n_Wrap(cor_cera20c, 0)
printVarSummary(cor_cera20c_mean)

year_all = ispan(1900, 2022, 1)
cor_all = new((/9,dimsizes(year_all)/), float, cor_ERA5@_FillValue)
setDim(cor_all,1,"year",year_all)

cor_all(0,{min(cor_ERA5&year):max(cor_ERA5&year)}) = cor_ERA5
cor_all(0,{min(cor_jra55&year):max(cor_jra55&year)}) = cor_jra55
cor_all(0,{min(cor_ncep1&year):max(cor_ncep1&year)}) = cor_ncep1
cor_all(0,{min(cor_ncep2&year):max(cor_ncep2&year)}) = cor_ncep2
cor_all(0,{min(cor_cfs&year):max(cor_cfs&year)}) = cor_cfs
cor_all(0,{min(cor_erai&year):max(cor_erai&year)}) = cor_erai
cor_all(0,{min(cor_cera20c_mean&year):max(cor_cera20c_mean&year)}) = cor_cera20c_mean
cor_all(0,{min(cor_era20c&year):max(cor_era20c&year)}) = cor_era20c
cor_all(0,{1900:max(cor_20th&year)}) = cor_20th({1900:})
cor_all_mean = dim_avg_n_Wrap(cor_all, 0)
printVarSummary(cor_all_mean)

;# 画图（带EOF，3张图,另一套配色）
year := ispan(1958, 2022, 1)
year0 := ispan(1958, 1978, 1)
year1 := ispan(1979, 1998, 1)
year2 := ispan(1999, 2022, 1)
plot := newPlots(8)
fileName = "fig1"
wks := gsn_open_wks(png,fileName)
labelColor = "#434343"

;# Fig1a
opt := True
t = t_value(window-2)
notDrawAndFrame(opt)
  opt@minmax = (/-0.5,0.85/)
  opt@vpWidthF = 1.45
  opt@vpHeightF = 0.55
  opt@gsnXYBarChart = False
  opt@extend = -9
  opt@xyLineThicknessF = 3.
  ; opt@gsnLeftString = "~F22~b~F21~   Sliding Cor (WAJ, EAJ)"
  opt@gsnLeftString = "~F22~a~F21~"
  opt@gsnLeftStringFontHeightF = 0.035
  opt@gsnLeftStringOrthogonalPosF = 0.05
  opt@gsnLeftStringParallelPosF = -0.05
  ; opt@gsnLeftStringParallelPosF = 0.2
  opt@gsnRightString = "~F22~Evolution of Corr (WAJ, EAJ)"
  opt@gsnRightStringFontHeightF = 0.035
  opt@gsnRightStringOrthogonalPosF = 0.02
  ; opt@gsnRightStringParallelPosF = 0.7
  opt@gsnRightStringParallelPosF = 0.48
  ; opt@gsnRightStringFontColor = "#222222"
  opt@gsnRightStringFontColor = "white"
  opt@tmYLValues = (/-0.3,0,0.3,0.6/)
  opt@tmYLLabelFontHeightF = 0.03
  opt@tmYLLabelFontColor = labelColor
  opt@tmXBLabelFontHeightF = 0.03
  opt@tmXBLabelFontColor = labelColor
  ; opt@tmXBLabelFont = 5
  opt@trXMinF = 1909
  opt@trXMaxF = 2015
  opt@tmXTBorderOn = False
  opt@tmYRBorderOn = False
  opt@tmYROn = True
  opt@tmYRMode = "Explicit"
  ; opt@tmYRValues = (/t@r95,t@r999/)
  opt@tmYRValues = (/t@r95/)
  opt@tmYRLabels = (/"95%","99.9%"/)
  opt@tmYRLabelsOn = True
  opt@tmYRLabelFontColor = "DodgerBlue"
  opt@tmYRLabelFont = 22
  opt@tmYRLabelFontHeightF = 0.025
  opt@tmYRLabelDeltaF = -1.55
  opt@tmYRMajorLineColor = "DodgerBlue"
  opt@tmYRMajorThicknessF = 5
  opt@tmYRMajorLineColor = "transparent"
  opt@xyLineColor = "#076483"
  ; opt@xyLineColor = "#8ab18a"
  ; opt@xyLineColor = "MediumPurple"
  opt@tiXAxisString = "Mid-year of 21-yr sliding window"
  opt@tiXAxisFontHeightF = 0.025
  opt@tiXAxisOffsetYF = 0.
  opt@tiXAxisFontColor = "Grey29"
  opt@gsnYRefLineColor = "transparent"
  opt@Yref = -10;不显示
  opt@vpClipOn = False
  ; opt@gsnYRefLine = -10
  ; opt@tmXTBorderOn = False
  ; opt@tmYLFormat = "0@;*.2f"
plot(0) = plot_ts(wks,cor_era20c,opt)

; txres                       := True
;   txres@txPerimOn             = False
;   txres@txBackgroundFillColor = "#e9e0ff"
;   txres@txFontHeightF         = 0.033
;   ; txres@txFontColor = "dimg"
;   txres@txFontOpacityF = 0.8

;   txid := gsn_create_text(wks, "Evolution of Corr (WAJ, EAJ)", txres)

; amres := True
;   amres@amJust           = "TopCenter"
;   amres@amOrthogonalPosF = -0.62
; annoid := gsn_add_annotation(plot(0), txid, amres)  ; Attach string to plot; using default values.

res_box := True
  ; res_box@gsFillColor = "#ded3fa"
  ; res_box@gsFillOpacityF = 0.5
  ; res_box@gsFillColor = "#9AC392"
  res_box@gsFillColor = "#368237"
  ; res_box@gsFillColor = "#C52326"
  ; res_box@gsFillColor = "#C52326"
  ; res_box@gsFillOpacityF = 0.4
; add_box(plot(0),1950,1.0,14,0.7,res_box)
; x := 0.495
; x := 0.2795;最左端
x := 0.2895;最左端.加粗下
y := 0.99
; width := 0.21
width := 0.22
height := 0.029
polyXF := (/x-width,x-width,x+width,x+width,x-width/)
polyYF := (/y-height,y+height,y+height,y-height,y-height/)
gsn_polygon_ndc(wks, polyXF, polyYF, res_box)

pgres := (/-10,10,min(year2)-0.5,2019/)
  pgres@gsFillOpacityF = 0.1
  pgres@gsFillColor = "#ff8747"
add_fillBox(plot(0),pgres)

  opt@xyLineThicknessF = 2.
  opt@xyLineColor = "#8ab18a"
add_ts(plot(0),cor_20th,opt)
line := "20thCRV3"
  line@txFontHeightF = 0.024
  line@gsLineThicknessF = 3.
  line@txJust = "CenterLeft"
  line@txFont = 21
  line@txOffsetXF = 1
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern  
  ; print(ismissing(line@gsLineDashPattern))
; add_line(plot(0),(/1912,1917/),(/-0.4,-0.4/),line)
add_text(plot(0),line,1976.5,-0.4)

text := "99.9%"
  text@txFontColor = "red"
  text@txFont = 22
  text@txFontHeightF = 0.025
add_string(plot(0),text,1.035,1)

  opt@xyLineColor = "MediumPurple"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 4
add_ts(plot(0),cor_cera20c_mean,opt)
; add_ts(plot(0),cor_era20c,opt)
rshade := True
  ; rshade@gsFillColor = "MediumPurple"
  rshade@gsFillColor = "MediumPurple"
addSpreading(plot(0),cor_cera20c,rshade)
line = "CERA-20C"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1938,1943/),(/-0.4,-0.4/),line)
add_text(plot(0),line,1989.5,-0.4)






tval := (/t@r95/)
  tval@polyYRefDashPattern = 1
  tval@polyYRefMin = 1988
  tval@polyYRefMax = 2014
add_Yref(plot(0),tval)
tval := (/t@r999/)
  tval@polyYRefDashPattern = 1
  tval@polyYRefMin = 1988
  tval@polyYRefMax = 2014
  tval@polyYRefColor = "red"
add_Yref(plot(0),tval)
line = "ERA-5"
  line@txFontColor = "Red"
  line@gsLineColor = "Red"

; add_line(plot(0),(/1912,1917/),(/0.75,0.75/),line)
add_text(plot(0),line,1911,-0.4)

  ; opt@xyLineColor = "#3434ff"
  opt@xyLineColor = "DimGrey"
  opt@xyLineThicknessF = 10.
add_ts(plot(0),cor_ncep2,opt)
line = "NCEP-DOE"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1912,1917/),(/0.55,0.55/),line)
add_text(plot(0),line,1937.5,-0.4)
  opt@xyLineColor = "#f3a13c"
  opt@xyLineThicknessF = 7
line = "NCEP/NCAR"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@yLineColor
; add_line(plot(0),(/1940,1945/),(/0.55,0.55/),line)
add_text(plot(0),line,1952,-0.4)
add_ts(plot(0),cor_ncep1,opt)

  ; opt@xyLineColor = "Magenta"
  opt@xyLineColor = "#3434ff"

  opt@xyLineThicknessF = 7.
  opt@xyDashPattern = 0
add_ts(plot(0),cor_erai,opt)
  opt@xyLineThicknessF = 7.
line = "ERA-I"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern
; add_line(plot(0),(/1960,1965/),(/-0.4,-0.4/),line)
add_text(plot(0),line,1929,-0.4)

  opt@xyLineColor = "#72c8e4"
  opt@xyLineThicknessF = 3.
  opt@xyDashPattern = 0
; add_ts(plot(0),cor_era20c,opt)
line = "ERA-20C"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1965,1970/),(/-0.4,-0.4/),line)
add_text(plot(0),line,2003.5,-0.4)

;   opt@xyLineColor = "green"
;   opt@xyLineThicknessF = 7.
;   opt@xyDashPattern = 0
; add_ts(plot(0),cor_era20cm,opt)
; line = "ERA-20CM"
;   line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1965,1970/),(/-0.4,-0.4/),line)

opt@xyLineColor = "ForestGreen"
opt@xyLineThicknessF = 7.
  opt@xyDashPattern = 0
add_ts(plot(0),cor_jra55,opt)
line = "JRA-55"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern

; add_line(plot(0),(/1935,1940/),(/0.75,0.75/),line)
add_text(plot(0),line,1919.5,-0.4)

  opt@xyLineColor = "Black"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 7.
  ; opt@xyDashPattern = 2
add_ts(plot(0),cor_cfs,opt)
line = "CFSR"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern
; add_line(plot(0),(/1970,1975/),(/0.55,0.55/),line)
add_text(plot(0),line,1968,-0.4)

  opt@xyLineColor = "Red"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 12
add_ts(plot(0),cor_ERA5,opt)

;# Fig1a 地球
opt := True
notDrawAndFrame(opt)
  opt@vpWidthF = 1.2
  opt@vpHeightF = 0.8
  opt@tmXBTickSpacingF = 40
  opt@tmYLTickSpacingF = 25
  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 35.
  opt@mpLandFillColor = "transparent"
  opt@mpCenterLonF = 85
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 67
  opt@mpMinLatF = 7
  opt@mpMaxLonF = 150
  opt@mpMinLonF = 0
  opt@mpPerimOn         = False 
  opt@gsnMaximize = False
  opt@mpGeophysicalLineThicknessF = 0.5
  ; opt@mpGridAndLimbOn = True
  opt@mpGridLineThicknessF = 0.5
  opt@mpGridLonSpacingF = 30
  opt@mpGridLatSpacingF = 15
  ; opt@vpXF = -0.1
  ; opt@mpGeophysicalLineColor = "#59cbcd"
  ; opt@mpGeophysicalLineThicknessF = 3
range := (/10,80,-12.5,191/)

plot(1) = plot_base(wks,range,opt)
type := "u"
  type@source = "ERA5"
  type@range = (/10,80,20,191/)
  type@year := ispan(1961, 2020, 1)
  type@level = 200
  type@month = month
opt := True
notDrawAndFrame(opt)
  opt@lbLabelBarOn = True
  opt@cnLinesOn = False
  opt@lbLabelFormat = "%0.0f"
  opt@cnLevels = (/20,22,24,26,28,30,32,34/)
  opt@cnFillColors = (/"#ffffff","#d9e6d5","#c3d9bb","#aecda4","#9ac392","#89bc86","#79b77a","#4ea250","#368237"/)
  type@year := year
; add_clim(plot(1),type,range,opt)
  opt@lbLabelFormat = "%0.1f"
  opt@lbLabelFontHeightF = 0.025
  opt@lbTitleString = "U200 (m s~S~-1~N~)"
  opt@lbTitleOffsetF = 0.2
  opt@lbTitlePosition = "Right"
  opt@lbTitleDirection = "Across"
  opt@lbTitleFontHeightF = 0.025
  opt@lbTitleAngleF = 90
  opt@lbBoxLineThicknessF = 2
  opt@lbBoxLinesOn = True
  opt@lbBoxSeparatorLinesOn = False
  opt@pmLabelBarWidthF = 0.07
  opt@pmLabelBarHeightF = 0.55
  opt@pmLabelBarOrthogonalPosF = 0.0
  opt@pmLabelBarParallelPosF = 0.5
  opt@lbOrientation = "Vertical"

  opt@cnLinesOn = False
  opt@cnLineThicknessF = 5.
  opt@cnLineDashPattern = 0
  opt@cnLevels := (/22,24,26,28,30,32,34/)
  ; opt@cnFillColors := (/"transparent","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  opt@cnFillColors := (/"white","#c3d9bb","#aecda4","#9ac392","#89bc86","#79b77a","#4ea250","#368237"/)
  opt@lbLabelStride = 2
  opt@lbLabelFormat = "%0.0f"
  print(type)
add_clim(plot(1),type,range,opt)
  opt@cnLinesOn = True
  opt@cnFillOn = False
  opt@cnLevels := (/3.5,4,4.5,5,5.5,6/)
  opt@cnLineColor = "#206e22"
  opt@cnLineThicknessF = 3
add_cn(plot(1),U200_sd,range,opt)
; res_topo := True
;   res_topo@mode = "shading"
;   res_topo@cnLineColor = "Black"
;   res_topo@cnLineThicknessF = 1.
;   res_topo@cnFillOpacityF = 0.7
; add_topo(plot(1),range,3000,res_topo)
  line := ""
    line@txFontHeightF = 0.04
    line@txFont = 22
    line@txJust = "CenterLeft"
    line@txOffsetXF = 4
    line@txOffsetYF = -1
    ; line@txLineHeightF = 1.
    line@gsLineThicknessF = 7
    ; line@gsLineDashPattern = 1
    line@txJust = "BottomLeft"
    line@txOffsetYF = -25
    line@txOffsetXF = -145
    line@txOffsetXF = -145
    line@txOffsetYF = -10
    line@gsLineThicknessF = 20
    line@gsLineDashPattern = 0
    line@gsLineColor = "#0000ff"
    line@txJust = "BottomLeft"
    line@txFontColor = "#0000ff"
  lat_JA_WAJ = lat_JA({40:80})
  lat_JA_EAJ = lat_JA({90:123})
  add_line(plot(1),lat_JA_WAJ&lon,lat_JA_WAJ,line)
    line@gsLineColor = "red"
    line@txFontColor = "red"
  add_line(plot(1),lat_JA_EAJ&lon,lat_JA_EAJ,line)
box := (/0,90,rangeEAJ(2),rangeEAJ(3)/)
  box@gsLineThicknessF = 8.
  box@gsFillOpacityF = 0.2
  box@gsLineColor = "#0000ff"
  box@gsFillColor = "#0000ff"
; add_lineBox(plot(1),box)
; add_fillBox(plot(1),box)
box = (/0,90,rangeWAJ(2),rangeWAJ(3)/)
  box@gsLineColor = "#33a0ff"
  box@gsFillColor = "#33a0ff"
; add_lineBox(plot(1),box)
; add_fillBox(plot(1),box)
text := "WAJ"
  text@txFontColor = "#0000ff"
  text@txFontHeightF = 0.08
  text@txFont = 22
  text@txAngleF = -21
add_text(plot(1),text,60,31)
text = "EAJ"
  text@txFontColor = "Red"
  text@txAngleF = 20
add_text(plot(1),text,105,30)



year := ispan(1958, 2022, 1)
year0 := ispan(1958, 1978, 1)
year1 := ispan(1979, 1998, 1)
year2 := ispan(1999, 2022, 1)
ts0 := ESWJ2
ranges := (/0,75,0,190/)
opt := True
notDrawAndFrame(opt)
  opt@vpHeightF = 0.55
  opt@vpWidthF = 0.85
  opt@tmYLLabelsOn = True
  ; opt@gsnLeftString = (/"EOF1 "+min(year0)+"-"+max(year0),min(year1)+"-"+max(year1),min(year2)+"-"+max(year2)/)
  opt@gsnLeftString = "~F22~b~F21~  U200"
  opt@gsnLeftStringFontHeightF = 0.055
  opt@gsnLeftStringParallelPosF = 0.03
  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 35.
  opt@mpLandFillColor = "transparent"
  opt@mpCenterLonF = 85
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 67
  opt@mpMinLatF = 7
  opt@mpMaxLonF = 170
  opt@mpMinLonF = 0
  opt@mpGridAndLimbOn = True
  opt@mpGridLineThicknessF = 0.5
  opt@mpGridLonSpacingF = 30
  opt@mpGridLatSpacingF = 15
  ; opt@mpGridLineDashPattern = 1
  opt@mpGeophysicalLineColor = "#206e22"
  opt@mpPerimOn         = False 
  ; opt@txPerimOn
; fileName = folder+"change_in_mode"
; wks = gsn_open_wks(png,fileName)
plot(2) = plot_base(wks,ranges,opt)
  opt@gsnLeftString = "~F22~d~F21~  Heatwave"
plot(4) = plot_base(wks,ranges,opt)
  opt@gsnLeftString = "~F22~e~F21~  SPEI & PRW"
plot(5) = plot_base(wks,ranges,opt)
  opt@mpCenterLonF = 105
  opt@mpMaxLonF = 180
  opt@mpCenterLatF      = 25.
  opt@mpMinLatF = 0

  opt@gsnLeftString = "~F22~f~F21~  LWA & SH & TC"
plot(6) = plot_base(wks,ranges,opt)
  ; opt@mpCenterLonF = 85
  ; opt@mpMaxLonF = 150
  ; opt@mpCenterLatF      = 35.
  ; opt@mpMinLatF = 7
  opt@gsnLeftString = "~F22~g~F21~  Precip & WVT"
plot(7) = plot_base(wks,ranges,opt)

;# fig1b U200
type := "u"
  type@level = 200
  type@month = (/7,8/)
  type@source = "ERA5"
  type@range = ranges
opt := True
optreg := True
notDrawAndFrame(opt)
  opt@Scale = 0.7
  opt@gsnStringBold = True
  opt@gsnLeftString = "EOF1"
  opt@gsnRightString = "P1"
  opt@lbLabelBarOn = True
  opt@pmLabelBarWidthF = 0.55
  opt@pmLabelBarHeightF = 0.12
  opt@pmLabelBarParallelPosF = 0.51
  opt@pmLabelBarOrthogonalPosF = 0.05
  opt@lbLabelStride = 3
  opt@lbTitleString = "Correlation (p<0.10)"
  opt@lbTitlePosition = "Bottom"
  opt@lbBoxSeparatorLinesOn = False


  opt@detrend = False
  opt@cnFillDotSizeF = 0.004
  opt@cnFillScaleF = 1.5
  opt@tmYLLabelStride = 1
  opt@tmXBTickSpacingF = 40
  opt@tmXBLabelStride = 1
  opt@gsnContourNegLineDashPattern = 14
  opt@gsnRightStringFontHeightF = 0.04
    opt@cnLineThicknessF = 6
    opt@tmBorderThicknessF = 5
    ; opt@tiYAxisString = "Latitude"
    ; opt@tiYAxisOffsetXF = 0.025
    ; opt@tiXAxisString = "Longitude"
    ; opt@tiXAxisOffsetYF = -0.04
  opt@gsnLeftString = "EOF1"
  opt@gsnRightString = "P2"
  opt@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.55,-0.5,-0.45,-0.3783408,0.3783408,0.45,0.5,0.55,0.6,0.7,0.8,0.9/)
; add_cor(plot(2),ts0,type,ranges,opt)
optreg@cnFillOn = True
optreg@cnLinesOn = False
optreg@pmLabelBarWidthF = 0.5
optreg@pmLabelBarHeightF = 0.1
optreg@pmLabelBarOrthogonalPosF = 0.10
optreg@cnLineThicknessF = 2.
optreg@Scale = 1.
optreg@smoothing = True
; optreg@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
; optreg@cnLevels = (/-4,-3.5,-3,-2.5,-2,-1.5,-1,-0.5,0.5,1,1.5,2,2.5,3,3.5,4/)
; optreg@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnFillColors = (/"#ffffff","#d9e6d5","#c3d9bb","#aecda4","#9ac392","#89bc86","#79b77a","#4ea250","#368237"/)
; optreg@cnFillColors = (/"#287029","#409441","#50b852","#6cbc68","#87c27b","#9ac392","#CCE6C7","#d9e6d5","#FFFFFF","#FEF5C7","#ffea84","#FEC554","#FEA52C","#ff7c4c","#F4602A","#d73729","#c51707"/)
optreg@cnFillColors = (/"#26702c","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
optreg@cnLevels = (/-3,-2,-1.5,-1,-0.5,0.5,1,1.5,2,3/)
optreg@lbLabelFormat = "%0.1f"
optreg@lbLabelStride = 3
optreg@lbLabelFontHeightF = 0.025
optreg@lbTitleString = "U200 (m s~S~-1~N~)"
optreg@lbTitlePosition = "Bottom"
optreg@lbTitleFontHeightF = 0.025
optreg@test = True
optreg@cnFillDotSizeF = 0.003
optreg@cnFillScaleF = 0.95
optreg@cnFillDotOpacityF = 0.8

; optreg@mode = "hatching"
; optreg@hatchingPattern = 8
; optreg@cnFillScaleF = 0.9

; optreg@cnLineLabelsOn = True
; optreg@cnLineLabelInterval = 1
; ; optreg@cnLineLabelBackgroundColor = "transparent"
; optreg@cnLineLabelFontColor = "#206e22"
; optreg@cnLineLabelFont = 22
; optreg@cnLineLabelFontHeightF = 0.02
add_reg(plot(2),ts0,type,ranges,optreg)

  opt@cnLevels := 20
  opt@cnLineThicknessF = 10
  opt@cnLineColor := "#eece00"
  opt@Scale = 1
type@year = year  
; add_clim(plot(0),type,ranges,opt)
; add_clim(plot(1),type,ranges,opt)
; add_clim(plot(2),type,ranges,opt)

  ;   line@gsLineColor = "#0000ff"
  ; add_line(plot(0),lat_JA0&lon,lat_JA0,line)

; rec = regCoef_n(x, y, dims_x, dims_y)

;# fig1c EWJA 
ts := dim_rmvmean_Wrap(ESWJ({year2}))
opt := True
notDrawAndFrame(opt)
  opt@gsnLeftString = "~F22~c~F21~  EWJA Index"
  opt@gsnLeftStringFontHeightF = 0.035
  opt@gsnLeftStringOrthogonalPosF = 0.02
  opt@gsnLeftStringParallelPosF = 0.03
  opt@gsnRightString = "PC1"
  opt@gsnRightStringFontColor = "Firebrick1"
  opt@gsnRightStringFontHeightF = 0.035
  opt@gsnRightStringOrthogonalPosF = 0.02
  opt@gsnRightStringParallelPosF = 0.95
  opt@tiXAxisString = "Year"
  opt@tiXAxisFontHeightF = 0.025
  opt@tiYAxisString = "m s~S~-1~N~"
  opt@tiYAxisFontHeightF = 0.025
  opt@tiYAxisOffsetXF = 0.01
  opt@tmXBTickSpacingF = 10
  opt@tmXBTickStartF = 1960
  opt@tmYLFormat = "%0.0f"
  opt@vpHeightF = 0.35
  opt@vpWidthF = 0.5
  opt@tmXBLabelFontHeightF = 0.025
  opt@tmXBLabelFontColor = labelColor
  opt@tmYLLabelFontHeightF = 0.025
  opt@tmYLLabelFontColor = labelColor
  opt@tmYLValues = (/-6,-3,0,3,6/)
  ; opt@tmYLFormat = "%0.0f"
  ; opt@trYMaxF = 7
  ; opt@trYMinF = -7
  opt@minmax = (/-2.8,2.8/)*3.04
  ; opt@tmYLLabelFont = 22
  opt@tmYROn = True
  opt@tmYUseLeft = False
  opt@tmYRMinorOn = False
  ; opt@tmYRValues = (/-7.5,-5,-2.5,0,2.5,5,7.5/)
  opt@tmYRValues = (/-3,-2,-1,0,1,2,3/)*stddev(ESWJ)
  opt@tmYRLabelsOn = True
  opt@tmYRLabelFontHeightF = 0.025
  opt@tmYRLabelFontColor = "Firebrick1"
  opt@tmYRMode = "Explicit"
  opt@tmYRLabelDeltaF = -0.5
  opt@tmYRMajorThicknessF = 5
  opt@gsnXYBarChartBarWidth = 0.5
  ; opt@tmYRTickStartF = -4
  ; opt@tmYRTickEndF = 4
  opt@tmYRLabels = (/"-3","-2","-1","0","1","2","3"/)
  ; opt@gsnXYBarChartColors = "#F1CD5C"
  ; opt@gsnXYBarChartColors = "#69b2fc"
  opt@gsnXYBarChartColors = "#353535"
  opt@gsnXYBarChartFillOpacityF = 0.8
  opt@gsnXYBarChartBarWidth = 0.7

  ; opt@tmYRLabelFontHeightF = 0.01
  ; opt@tmYRLabelFontColor = "tomato"
; plot(0) = gsn_csm_xy(wks, Jet_ERA5&year, Jet_ERA5, opt)
; print(combined_index)
; combined_index = (/dtrend_leftdim(combined_index, True)/)
; print(stddev(ts))
; ts = (/dtrend_leftdim(ESWJ, True)/)
; ts := combined_index
plot(3) = plot_ts(wks,ts,opt)
resY := True 
  resY@tiYRAxisStringFontHeightF = 0.025
  resY@tiYRAxisOffsetXF = 0.01
  resY@tiYRAxisFontColor = "Firebrick1"
add_YRAxisString(plot(3),"std. dev.",resY)

ts0 := EAJ0(0,:)
ts1 := EAJ1(0,:)  
ts2 := EAJ2(0,:) 

opt := True
notDrawAndFrame(opt)
  opt@gsnLeftString = "ESWJ"
  opt@gsnLeftStringFontHeightF = 0.015
  opt@gsnLeftStringOrthogonalPosF = 0.02
  opt@gsnLeftStringParallelPosF = 0.03
  opt@tiXAxisString = "Year"
  opt@tiXAxisFontHeightF = 0.012
  opt@tmXBLabelFontHeightF = 0.01
  opt@tmYLLabelFontHeightF = 0.01
  ; opt@vpHeightF = 0.05
  ; opt@vpWidthF = 0.905
  ; opt@vpXF = 0.05
  ; opt@vpYF = 0.57
  opt@tmXBTickSpacingF = 10
  opt@tmXBTickStartF = 1960
; ; plot(0) = gsn_csm_xy(wks, Jet_ERA5&year, Jet_ERA5, opt)
; plot_ESWJ = plot_ts(wks,dim_standardize_Wrap(combined_index, 0),opt)
opt@xyLineColor = "DodgerBlue"
; print(t_value(18))
opt@xyLineThicknessF = 10
ts2_amp := ts2*stddev(ESWJ)
copy_VarCoords(ts2, ts2_amp)
opt@xyLineColor = "firebrick1"
opt@xyMarkLineMode = "MarkLines"
opt@xyMarker = 4
opt@xyMarkerSizeF = 0.03
; opt@xyMarkerThicknessF
add_ts(plot(3),ts2_amp,opt)
text := "R = "+sprintf("%0.2f", escorc(ts0, ESWJ({year0})))+" (p<0.01)"
  text@txFontHeightF = 0.028
  text@txFontColor = "DodgerBlue"
  ; text@txFont = 22
; add_text(plot(3),text,1965,-6.5)
; add_text(plot(3),text,1965,-6.)

text = "R = "+sprintf("%0.2f", escorc(ts1, ESWJ({year1})))+" (p<0.05)"
  text@txFontColor = "#00a200"
; add_text(plot(3),text,1987,-6.)
; text = "U200_PC1 R = "+sprintf("%0.2f", escorc(ts2, ESWJ({year2})))+" (p<0.01)"
text = "R = "+sprintf("%0.2f", escorc(ts2, ESWJ({year2})))+", p<0.001"
  text@txFontColor = "red"
  ; text@txFontColor = "White"
  ; text@txBackgroundFillColor = "#ff9b89"
  ; text@txFontOpacityF = 0.5
add_text(plot(3),text,2007,-6.9)
box := (/2005,-6,0.5,0.1/)
; res_box := True
;   res_box@gsFillColor = "#ff9b89"
; add_box(plot(3),2007,-5.75,14,1.7,res_box)

;# fig1d 热浪
type := "net75p"
  type@source = "ERA5"
  type@month := (/7,8/)
  type@range := ranges
  type@level = 200
  type@year = year1
opt := True
notDrawAndFrame(opt)
  opt@Scale = 1.
  opt@multi = 1.0
  opt@detrend = False
  opt@cnLineThicknessF = 2
  ; opt@cnLinesOn = t
  opt@gsnContourNegLineDashPattern = 2
  opt@vector = False
  opt@dots = False
  opt@xReverseColors = True  
  ; opt@tmYLLabelStride = 1
  opt@tmXBLabelStride = 1
  opt@tmXBLabelFontHeightF = 0.025
  opt@tmYLLabelsOn = True
  opt@tmYLLabelFontHeightF = 0.025
  opt@tmXBTickSpacingF = 40
  opt@tmYLTickSpacingF = 25
  opt@lbLabelBarOn = False
  ; opt@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnLevels = (/-1.0,-0.9,-0.8,-0.7,-0.6,-0.5,-0.4,-0.3,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0/)
  ; opt@lbLabelFormat = "%0.0f"
  ; opt@gsnMaximize = True
  opt@cnFillScaleF = 1.
  opt@lbLabelBarOn = True
  opt@lbLabelFormat = "%0.0f"
  opt@lbLabelFontHeightF = 0.025
  opt@lbBoxSeparatorLinesOn = False
  opt@pmLabelBarHeightF = 0.1
  opt@pmLabelBarWidthF = 0.5
  opt@pmLabelBarOrthogonalPosF = 0.1
  opt@pmLabelBarParallelPosF = 0.49
  opt@lbTitleString = "Heatwave (days month~S~-1~N~)"
  opt@lbTitleAngleF = 0
  opt@lbTitleOffsetF = 0.1
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleDirection = "Across"
  opt@lbTitleFontHeightF = 0.025
  opt@lbOrientation = "Horizontal"
  opt@smoothing = True
  ; opt@cnFillColors := (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnLevels := (/-6,-5,-4,-3,-2.5,-2,-1.5,-1,1,1.5,2,2.5,3,4,5,6/)
  ; opt@cnFillColors = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#f17c22","#ff0000","#b02418"/)
  ; ; opt@cnFillColors := (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnLevels := (/-7,-5,-3,-1,1,3,5,7,9/)
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLevels = (/-3,-2,-1.5,-1,-0.5,0.5,1,1.5,2,3/)*2
  opt@lbLabelStride = 3
  opt@cnFillDotSizeF = 0.005
  opt@stipplingColor = "white"
  ; opt@cnFillPattern
  opt@mode = "hatching"
  opt@hatchingPattern = 8
  opt@hatchingColor = "#dadada"
  opt@cnFillScaleF = 0.6
  ; opt@cnFillScales = (/0.5,0.5,0.5,0.5,0.5/)
  opt@cnLineThicknessF = 10
  ; opt@cnfill
  ; opt@cnFillOpacityF = 0.1
add_reg(plot(4),ESWJ2,type,ranges,opt)


;# fig.2e SPEI
type := "spei"
  type@source = "spei"
  type@month := (/7,8/)
  type@range := ranges
  type@level = 500
opt := True
  ; opt@multi = 2.0
  opt@gsnDraw = False
  opt@gsnFrame = False
  opt@detrend = False
  opt@cnLineThicknessF = 2
  opt@vector = False
  opt@dots = False
  ; opt@reverseColors = True
  ; opt@tmYLLabelStride = 1
  ; opt@vpHeightF = 0.45
  ; opt@vpWidthF = 0.9
  opt@lbLabelBarOn = True
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLevels = (/-2.5,-2,-1.5,-1,-0.5,0.5,1,1.5,2,2.5/)*1.6
  ; opt@cnLevels = (/-1.0,-0.9,-0.8,-0.7,-0.6,-0.5,-0.4,-0.3,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0/)
  opt@lbLabelFormat = "%0.2f"
  opt@gsnMaximize = True
  opt@cnFillDotSizeF = 0.003
  opt@cnFillScaleF = 1.0
  opt@stipplingColor = "white"
  opt@smoothing = True
  ; opt@multi = 1000
  ; opt@Scale = 0.15
  opt@Scale = 0.1
  ; opt@relative = False
  opt@pmLabelBarWidthF = 0.5
  opt@pmLabelBarHeightF = 0.1
  opt@pmLabelBarOrthogonalPosF = 0.1
  opt@lbTitleString = "SPEI"
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleOffsetF = 0.2
  opt@lbTitleFontHeightF = 0.025
  opt@lbLabelFontHeightF = 0.025
  opt@lbLabelStride = 3
  opt@lbBoxSeparatorLinesOn = False
  opt@reverseColors = True
  opt@mode = "hatching"
  opt@hatchingPattern = 8
  opt@cnFillScaleF = 0.5
  opt@hatchingColor = "White"
; add_cor(plot(0),Jet1,type,ranges,opt)
add_reg(plot(5),ESWJ2,type,ranges,opt)


type = "PRW"
  type@level = 850
  type@source =  "ncep2"
  type@range(0) = 0
  opt@lbLabelFormat = "%0.1f"
  opt@Scale = 0.3
  opt@multi := 1
  ; opt@pmLabelBarOrthogonalPosF = 0.2
  opt@lbTitleString = "Precipitable Water (kg m~S~-2~N~)"
  opt@cnFillOn = False
  opt@cnLinesOn = True
  opt@cnLineThicknessF = 8
  opt@gsnContourNegLineDashPattern = 1
    ; opt@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  opt@cnLineColors = (/"#1B71B6","#2392C9","#28A0CE","#4EC0D9","#F28D75","#EE6B54","#EA463B","#E82229"/)
  ; opt@cnLineColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLevels := (/-5,-4,-3,-2,2,3,4,5/)
  ; opt@cnMonoLineColor = True
  opt@test = False
  ; opt@lbLabelBarOn = True
add_reg(plot(5),ESWJ2,type,ranges,opt)
type = "CE"
ts_CE := ESWJ2({ispan(1999, 2021, 1)})
  opt@mode = "stippling"
  opt@cnFillOn = False
  opt@cnLinesOn = False
  opt@cnFillScaleF = 1.0
  opt@cnFillDotSizeF = 0.0035
  opt@test = True
; opt@stipplingColor = "#fdcc38"
  opt@stipplingColor = "white"
  opt@lbBoxSeparatorLinesOn = False
add_reg(plot(4),ts_CE,type,ranges,opt)
add_reg(plot(5),ts_CE,type,ranges,opt)
;# fig.2f
type := "lwa"
  ; type@source = "ersstv5"
  type@source = "era5"
  type@month = (/7,8/)
  type@range := (/0,90,-80,260/)
  type@level = 200
opt := True
notDrawAndFrame(opt)
  opt@cnFillDotSizeF = 0.003
  opt@cnFillDotOpacityF = 0.9
  opt@cnFillScaleF = 1.
  opt@stipplingColor = "white"
  opt@lbLabelBarOn = True
  opt@lbLabelStride = 1
  opt@smoothing = True
  opt@lbTitleString = "LWA (m s~S~-1~N~)"
  ; opt@lbTitleJust = "CenterLeft"
  opt@lbTitlePosition = "Right"
  ; opt@cnFillColors := (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#bd932a","#A57E1E"/)
  ; opt@cnFillColors := (/"#51538e","#7572a3","#b3aec8","#eae7ed","#FFFFFF","#f6d9d6","#eb9998","#f48176","#ff4134","#d70e00"/)
  opt@lbLabelFormat = "%0.1f"
  opt@lbBoxSeparatorLinesOn = False

  opt@cnLevels := (/-6,-4,-2,-1,1,2,4,5,6/)
  opt@cnFillColors = (/"#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  ; opt@cnLevels = (/-3,-2,-1.5,-1,-0.5,0.5,1,1.5,2,3/)*2
  opt@lbLabelFontHeightF = 0.022
  opt@lbTitleFontHeightF = 0.022
  opt@lbLabelStrings = (/"-2.4","","-0.8","","0.4","","1.6","","2.4"/)
  ; opt@lbLabelConstantSpacingF = 0.6
  ; opt@lbLabelAngleF = -45
  ; opt@lbLabelFontHeightF = 0.025
  opt@Scale = .4
  ; opt@multi = 2.0
; plot@isShaded(1) = True
type@year = ts&year
method := "anom"
lwa := process(type,method)
; printVarSummary(lwa)
lwa_reg := regCoef_n(ESWJ2, lwa, 0, 0)
copy_VarCoords(lwa(0,:,:), lwa_reg)
tem := lwa_reg({0:45},{0:180})
lwa_reg({0:45},{0:180}) = where(tem > 0, 0, tem)
lwa_reg({0:40},{50:120}) = 0
lwa_reg({0:25},{120:180}) = 0
opt@cnFillOn = True
opt@cnLinesOn = False
opt@pmLabelBarParallelPosF = 0.51
opt@lbTitleDirection = "Across"
  opt@pmLabelBarWidthF = 0.45
  opt@pmLabelBarHeightF = 0.09
  opt@pmLabelBarOrthogonalPosF = 0.18
add_cn(plot(6),lwa_reg,ranges,opt)
tval := get_tval(lwa_reg)
t := t_value(22)
res_test := True
notDrawAndFrame(res_test)
res_test@cnFillDotSizeF = 0.0035
res_test@cnFillScaleF = 1.2
  if(isatt(opt,"stipplingColor"))
    res_test@stipplingColor = opt@stipplingColor
  end if
  ; if(isatt(opt, "cnFillDotOpacityF"))then
  ;   res_test@cnFillOpacityF = opt@cnFillDotOpacityF
  ; end if
  ; if(isatt(opt, "dotDrawOrder"))then
  ;   res_test@dotDrawOrder = opt@dotDrawOrder
  ;   ; print(opt@dotDrawOrder)
  ; end if
  level = 90
  res_test@cnLevel = t@$("t"+level)$
  res_test@hatchingPattern = 8
  res_test@cnFillScaleF = 0.5
  res_test@hatchingColor = "White"
  ; add_hatching(plot(6),tval,ranges,res_test)
  ; add_hatching(plot(6),tval,ranges,res_test)
  ; add_hatching(plot(6),tval,ranges,res_test)
  ; add_hatching(plot(6),tval,ranges,res_test)
  ; add_hatching(plot(6),tval,ranges,res_test)

  res_test@cnFillDotSizeF = 0.003
  res_test@cnFillScaleF = 0.95
  res_test@cnFillDotOpacityF = 0.8
  add_dots(plot(6),tval,ranges,res_test)

;# TC
 opt@Scale = 1
  opt@detrend = True
  opt@cnLinesOn = True
  opt@cnMonoLineColor = False
  opt@cnLineColor = "Black"
  opt@cnLineThicknessF = 1
  delete(opt@cnLineColors)
  opt@cnFillOpacityF = 1.0
  opt@lbBoxSeparatorLinesOn = False

  ; add_cn(plot(1),tcCor,range,opt)
  opt@lbLabelBarOn = True
  opt@lbOrientation = "Horizontal"
  opt@pmLabelBarOrthogonalPosF = 0.05
  opt@pmLabelBarParallelPosF = 0.505
  opt@pmLabelBarWidthF = 0.27
  opt@pmLabelBarHeightF = 0.08
  opt@lbTitleString = "TC Track Density Corr"
  ; opt@lbTitleJust = "CenterCenter"
  opt@lbTitlePosition = "Right"
  opt@lbTitleDirection = "Across"
  opt@lbLabelStride = 1
  delete(opt@lbLabelStrings)
  ; opt@lbTitleAngleF = 90
  opt@lbTitleFontHeightF = 0.022
  ; opt@lbTitleOffsetF = 0.2
  opt@lbLabelFormat = "%0.1f"
  opt@lbLabelFontHeightF = 0.022
  opt@lbBoxLineThicknessF = 1
  opt@Scale = 1
  opt@detrend = True
  ; opt@cnFillColors := (/"#F6E9BC","#F1CD5C","#F0BF2A","#bd932a","#A57E1E"/)

  ; opt@cnFillColors := (/"transparent","#E6CC5D","#EB9E17","#e75c40"/)
  opt@cnFillColors := (/"transparent","#F6E9BC","#F1CD5C","#e99b00"/)
  opt@cnLineColors := (/"#ff748b","transparent","transparent"/)
  opt@cnLineThicknessF = 10
  ; opt@cnFillColors := (/"transparent","#F6E9BC","#F1CD5C","#F0BF2A"/)
  opt@cnLevels := (/t@r90,t@r95,t@r99/)
  opt@cnFillOn = True
  t = t_value(21)
  f_tcCor = addfile("/data/TC/TC-corr.nc", "r")
  tcCor := f_tcCor->a(0,0,:,{80:140})
  tcCor = (/where(tcCor .le. 0 .or. ismissing(tcCor), 0, tcCor)/)
  ; range = (/0,30,80,120/)
  add_cn(plot(6),tcCor,range,opt)

;# SAH和WNPSH气候态
    opt@detrend            = False
    opt@lbLabelBarOn       = False
    opt@cnLineThicknessF := 3.
    ; ranges = (/10,75,-90,210/)
    opt@lbBoxLineThicknessF = 15
    opt@cnFillOn = True
    opt@cnLinesOn = False
    opt@cnFillColors := (/"transparent","dodgerblue1"/)
    opt@cnLevels := (/SAH_level/)
    opt@cnFillOpacityF = 0.3
    opt@vcRefAnnoOn = True
    opt@vcRefAnnoParallelPosF = .22
    ; plot(0) = reg(wks,EAJII1,type,ranges,opt)
; add_cn(plot(1),SAH_clim1,ranges,opt)
add_cn(plot(6),SAH_clim1,ranges,opt)
    opt@cnLevels = (/WNPSH_level/)
    opt@cnFillColors := (/"transparent","tomato"/)
    opt@cnFillOn = True
    opt@cnLinesOn = False
; add_cn(plot(6),WNPSH_clim1,ranges,opt)
add_cn(plot(6),WNPSH_clim1,ranges,opt)
reso := True
notDrawAndFrame(reso)
      reso@cnLevelSelectionMode       = "ExplicitLevels"
      reso@cnFillOn                   = False
      reso@cnFillOpacityF = 0.4
      reso@lbLabelBarOn = False
      reso@cnLinesOn                  = True
      reso@cnLineThicknessF           = 15
      reso@cnLineLabelsOn             = False
      reso@gsnLeftString              = ""
      reso@gsnRightString             = ""
      reso@cnInfoLabelOn              = False
      reso@cnLabelDrawOrder           = "postdraw"
      reso@cnLineDrawOrder = "postdraw"
      reso@tmXBLabelsOn               = False
    ;   reso@cnLineDrawOrder            = "postdraw"
      range                           = (/00,90,90,ranges(3)/)
      reso@cnLevels                   = WNPSH_level
      ; reso@cnLevels := (/5865,5880/)
    reso@cnLineColor = "firebrick2"
    reso@cnLineDashPattern = 0
; add_cn(plot(6),WPSH_h,ranges,reso)
add_cn(plot(6),WPSH_h,ranges,reso)

    reso@cnLineDashPattern = 16
    reso@cnLineThicknessF           = 10
    reso@cnLineColor = "coral"
; add_cn(plot(6),WPSH_l,ranges,reso)
add_cn(plot(6),WPSH_l,ranges,reso)

    reso@cnLevels := SAH_level
    ; reso@cnLevels := (/14350,14400/)
    reso@cnLineThicknessF = 15
    reso@cnLineDashPattern = 0
    reso@cnLineColor = "dodgerblue3"
; add_cn(plot(6),SAH_h,ranges,reso)
add_cn(plot(6),SAH_h,ranges,reso)

    reso@cnLineDashPattern = 16
    reso@cnLineThicknessF = 10
    reso@cnLineColor = "deep sky blue"
; add_cn(plot(6),SAH_l,ranges,reso)
add_cn(plot(6),SAH_l,ranges,reso)
res_text := "TPH"
  res_text@txFont = 22
  res_text@txFontColor = "dodgerblue3"
  res_text@txFontHeightF = 0.04
  res_text@txFontThicknessF = 5
  res_text@txAngleF = -20
; add_text(plot(6),res_text,72,29)
add_text(plot(6),res_text,72,29)
  res_text = "WNPSH"
  res_text@txFontColor = "firebrick2"
  res_text@txFontThicknessF = 5
  res_text@txFontHeightF = 0.04
  res_text@txAngleF = 30
; add_text(plot(6),res_text,165,23)
add_text(plot(6),res_text,155,28)

;# fig.2g 降水
type = "precip"
  type@source = "GPCP"
  ; type@level = 1000
  type@month := (/7,8/)
opt := True
notDrawAndFrame(opt)
  opt@lbLabelFormat = "%0.1f"
  opt@multi := 1
  opt@Scale = 0.2
  opt@reverseColors = True
  opt@lbLabelBarOn = False
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLevels = (/-5,-4,-3,-2,-1,1,2,3,4,5/)
; delete(opt@cnFillColors)
; delete(opt@cnLevels)
; add_cor(plot(7),ts,type,ranges,opt)
ranges(0) = 0
  ; opt@mode = "hatching"
  ; opt@hatchingPattern = 8
  ; opt@cnFillScaleF = 0.5
  ; opt@hatchingColor = "White"
  opt@test = True
  opt@cnFillDotSizeF = 0.003
  opt@cnFillScaleF = 0.95
  opt@cnFillDotOpacityF = 0.8
  opt@lbBoxSeparatorLinesOn = False

add_reg(plot(7),ESWJ2,type,ranges,opt)
  type@source = "NOAA_Land"
  opt@lbOrientation = "Horizontal"
  opt@lbLabelBarOn = True
  opt@pmLabelBarWidthF = 0.5
  opt@pmLabelBarHeightF = 0.1
  opt@pmLabelBarOrthogonalPosF = 0.1
  opt@lbTitleString = "Precipitation (mm day~S~-1~N~)"
  opt@lbTitleFontHeightF = 0.025
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleDirection = "Across"
  opt@lbLabelFontHeightF = 0.025
  ; opt@lbTitleAngleF = 90
  opt@lbTitleOffsetF = 0.1
  opt@lbBoxSeparatorLinesOn = False

add_reg(plot(7),ESWJ2,type,ranges,opt)
;# 水汽输送
  type_vc := "water_vapor_flux"
    type_vc@level = 850
    type_vc@month = type@month
    type_vc@source = "era5"
    type_vc@range = type@range
    type_vc@range(0) = 10
  rvc := True
    rvc@vcRefMagnitudeF = 5
    rvc@vcLineArrowHeadMaxSizeF = 0.015
    rvc@vcLineArrowHeadMinSizeF = 0.01
    ; rvc@vcFillArrowMinFracWidthF = 0.1
    rvc@vcMinDistanceF = 0.075
    rvc@vcLineArrowThicknessF = 7
    rvc@test = True
    ; rvc@vcColorsOn = True
    ; rvc@vcLevels = (/5,10,15,20/)
    ; rvc@vcLevelColors = (/"White","Green","Blue","Red","Magenta"/)
    rvc@vcMinMagnitudeF = 2
    ; rvc@vcMaxMagnitudeF = 10
    ; rvc@vcMonoLineArrowColor = False
    rvc@vcRefAnnoParallelPosF = 1.05
    rvc@vcRefAnnoOrthogonalPosF = -1.4
    rvc@vcRefAnnoFontHeightF = 0.02
    rvc@vcRefAnnoPerimOn = False
    rvc@vcLineArrowColor = "DodgerBlue"
  add_reg_vc(plot(7),ESWJ2,type_vc,range,rvc)

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 5.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
range(2) = 40
add_topo(plot(1),range,3000,res_topo)
add_topo(plot(2),range,3000,res_topo)
add_topo(plot(4),range,3000,res_topo)
add_topo(plot(5),range,3000,res_topo)
add_topo(plot(6),range,3000,res_topo)
add_topo(plot(7),range,3000,res_topo)

;# 急流轴
line := ""
    line@txFontHeightF = 0.04
    line@txFont = 22
    line@txJust = "CenterLeft"
    line@txOffsetXF = 4
    line@txOffsetYF = -1
    ; line@txLineHeightF = 1.
    ; line@gsLineDashPattern = 1
    line@txJust = "BottomLeft"
    line@txOffsetYF = -25
    line@txOffsetXF = -145
    line@txOffsetXF = -145
    line@txOffsetYF = -10
    line@gsLineThicknessF = 20
    line@gsLineDashPattern = 0
    ; line@gsLineColor = "#eece00"
    line@gsLineColor = "#c872fe"
    line@txJust = "BottomLeft"
    line@txFontColor = "#0000ff"
  lat_JA_new := lat_JA({23:123})
  ; lat_JA_new := lat_JA({20:150})
  add_line(plot(2),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(4),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(5),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(6),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(7),lat_JA_new&lon,lat_JA_new,line)
;# 组图
resp := True
  resp@gsnFrame = False
  resp@gsnPanelScalePlotIndex = 1
  resp@gsnPanelYWhiteSpacePercent = 5.
  resp@gsnPanelRowSpec = True
  resp@gsnPanelXF = (/0.07,0.08,0.02,0.37,0.7,0.02,0.37,0.7/)
  resp@gsnPanelYF = (/0.96,0.96,0.50,0.5,0.5,0.22,0.22,0.22/)
  resp@gsnPanelScaleF = (/0.6,0.18,0.3,0.47,0.3,0.3,0.3,0.3/)
  resp@gsnMaximize = True
  ; resp@gsnPanelLeft = -0.1
  ; resp@gsnPanelDebug = True
  ; resp@gsnPanelGridYF = 0.4
gsn_panel(wks,plot,(/2,3,3/),resp)


frame(wks)
; delete(wks)
show(fileName+".png")
end