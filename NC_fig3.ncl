begin ;记录全局参数
  localpath := (/"/SSD1/","/SSD1/","/SSD1/","/home/llf/code/ncl/"/)
  call_stream = NewList("fifo")
  bufferPath = localpath(1)+"buffer/"
  bufferMode = "disabled"
  bufferIdList = NewList("fifo")
  bufferFileList = NewList("fifo")
  bufferCount = 0
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

undef("readCor")
function readCor(path)
local f,cor
begin
  f := addfile(path, "r")
  cor = f->cor
  return cor
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
  year01 := ispan(1958, 1998, 1)
  month = (/7,8/)
  rangeWAJ = (/40, 47, 45, 85/)
  rangeEAJ = (/40, 47, 90, 130/)
  setDim(year,0,"year",year)
  setDim(year0,0,"year",year0)
  setDim(year1,0,"year",year1)
  setDim(year01,0,"year",year01)
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
ESWJ01 := dim_standardize_Wrap(ESWJ({year01}), 0)
; print(ESWJ)
  type@range = rangeWAJ
U200 := process(type,method)
WAJ_index := calcJetAxisStrength(U200)
  type@range = rangeEAJ
U200 := process(type,method)
EAJ_index := calcJetAxisStrength(U200)
;# 投影指数
f = addfile("ESWJ_index.nc", "r")
EWJA = f->EWJA_modified

EWJA01 = dim_standardize_Wrap(EWJA({year01}), 0)
EWJA1 = dim_standardize_Wrap(EWJA({year1}), 0)
EWJA2 = dim_standardize_Wrap(EWJA({year2}), 0)
; EWJA01 = dim_standardize_Wrap(EWJA({year01}), 0)
; EWJA1 = dim_standardize_Wrap(EWJA({year1}), 0)
; EWJA2 = dim_standardize_Wrap(EWJA({year2}), 0)
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
ts1 := EWJA01
  ind_h1 := ind(ts1 .ge.  0.5)
  ind_l1 := ind(ts1 .le. -0.5)
; print(ESWJ2)
; print(year2(ind_h1))
; print(year2(ind_l1))
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
type@year := year01
SAH_clim1 := process(type,opt)

type@level = 500
type@range = (/10,50,100,190/)
type@year = year01
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

cor_ERA5 = readCor("cor_ERA5.nc")
cor_ncep2 = readCor("cor_ncep2.nc")
cor_ncep1 = readCor("cor_ncep1.nc")
cor_erai = readCor("cor_erai.nc")
cor_jra55 = readCor("cor_jra55.nc")
cor_cfs = readCor("cor_cfs.nc")
cor_20th = readCor("cor_20th.nc")
cor_era20c = readCor("cor_era20c.nc")
cor_era20cm = readCor("cor_era20cm.nc")
cor_cera20c = readCor("cor_cera20c.nc")
cor_cera20c_mean = dim_avg_n_Wrap(cor_cera20c, 0)

year_all = ispan(1900, 2022, 1)

;# 画图（带EOF，3张图,另一套配色）
year := ispan(1958, 2022, 1)
year0 := ispan(1958, 1978, 1)
year1 := ispan(1979, 1998, 1)
year2 := ispan(1999, 2022, 1)
plot := newPlots(9)
fileName = "NC_fig3"
wks := gsn_open_wks(png,fileName)
labelColor = "#434343"

;# 底图
itemType = "Nature"


ts0 := EWJA01
ts2 := EWJA2
; ts0 := ESWJ0
ranges := (/0,75,0,190/)
opt := True
notDrawAndFrame(opt)
  opt@vpHeightF = 0.55
  opt@vpWidthF = 0.85
  opt@tmYLLabelsOn = True
  ; opt@gsnLeftString = (/"EOF1 "+min(year0)+"-"+max(year0),min(year1)+"-"+max(year1),min(year2)+"-"+max(year2)/)
  opt@gsnLeftStringFontHeightF = 0.045
  opt@gsnLeftStringParallelPosF = 0.03
  opt@gsnLeftStringOrthogonalPosF = -0.09
  opt@gsnCenterStringFontHeightF = 0.045
  opt@gsnCenterStringOrthogonalPosF = 0.1
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
  opt@gsnLeftString = genItem("A",itemType)
  opt@gsnCenterString = "~F22~NET-Heatwave~F21~"
  opt@tiYAxisString = "P1"
  opt@tiYAxisAngleF = 0
  opt@tiYAxisFontHeightF = 0.045
  opt@tiYAxisFont = 22
plot(0) = plot_base(wks,ranges,opt)
  opt@gsnLeftString = genItem("B",itemType)
  opt@tiYAxisString = ""
  opt@gsnCenterString = "~F22~SPEI~F21~"
plot(1) = plot_base(wks,ranges,opt)
  opt@gsnCenterString = ""
  opt@tiYAxisString = "P2"
  opt@gsnLeftString = genItem("D",itemType)
plot(3) = plot_base(wks,ranges,opt)
  opt@tiYAxisString = ""
  opt@gsnLeftString = genItem("E",itemType)
plot(4) = plot_base(wks,ranges,opt)
  opt@tiYAxisString = ""
  ; opt@mpCenterLonF = 105
  ; opt@mpCenterLatF      = 30.
  ; opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 58
  opt@mpMinLatF = 8
  opt@mpMaxLonF = 200
  ; opt@mpMinLonF = 20
  opt@mpCenterLonF = 95

  opt@gsnLeftString = genItem("C",itemType)
  opt@gsnCenterString = "~F22~Rainfall~F21~"
plot(2) = plot_base(wks,ranges,opt)
  opt@tiYAxisString = ""
  opt@gsnCenterString = ""
  opt@gsnLeftString = genItem("F",itemType)
plot(5) = plot_base(wks,ranges,opt)
  opt@tiYAxisString = ""
  opt@gsnLeftString = genItem("I",itemType)+"  Clim Diff (P2 - P1)"
; plot(8) = plot_base(wks,ranges,opt)


;# fig1b U200
type := "u"
  type@level = 200
  type@month = (/7,8/)
  type@source = "ERA5"
  type@range = ranges
type@year = year  

  ;   line@gsLineColor = "#0000ff"
  ; add_line(plot(0),lat_JA0&lon,lat_JA0,line)

; rec = regCoef_n(x, y, dims_x, dims_y)

;# fig1c EWJA 
; ts := dim_rmvmean_Wrap(ESWJ({year2}))


; ts0 := EAJ0(0,:)
; ts1 := EAJ1(0,:)  
; ts2 := EAJ2(0,:) 

;# fig1A 热浪
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
  ; opt@cnLevels = (/-3,-2,-1.5,-1,-0.5,0.5,1,1.5,2,3/)*2
  opt@cnLevels = (/-2.5,-2,-1.5,-1,-0.5,0.5,1,1.5,2,2.5/)*2
  ; opt@cnLevels = (/-3,-2.5,-2,-1.5,-1,1,1.5,2,2.5,3/)*2
  opt@lbLabelStride = 3
  opt@cnFillDotSizeF = 0.005
  opt@stipplingColor = "white"
  ; opt@cnFillPattern
  opt@mode = "hatching"
  opt@hatchingPattern = 6
  opt@hatchingColor = "Grey90"
  ; opt@hatchingColor = "#dadada"
  ; opt@hatchingColor = "white"
  opt@hatchingRepeat = 5
  opt@cnFillScaleF = 0.8
  ; opt@cnFillScales = (/0.5,0.5,0.5,0.5,0.5/)
  opt@cnLineThicknessF = 10
  opt@lbLabelBarOn = False
  ; opt@cnfill
  ; opt@cnFillOpacityF = 0.1
add_reg(plot(0),ts0,type,ranges,opt)
  opt@lbLabelBarOn = True
add_reg(plot(3),ts2,type,ranges,opt)
  opt@lbLabelBarOn = True
  opt@test = True
  opt@Scale = 4.
; add_reg_diff(plot(6),ts0,ts2,type,ranges,opt)
; add_diff(plot(6),type,year01,year2,ranges,opt)

; add_reg(plot(5),ESWJ2,type,ranges,opt)


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
  ; opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#A2742A"/)
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
  opt@hatchingPattern = 6
  opt@hatchingRepeat = 5
  opt@cnFillScaleF = 0.8
  opt@hatchingColor = "Grey90"
  opt@lbLabelBarOn = False
; add_cor(plot(0),Jet1,type,ranges,opt)
add_reg(plot(1),ts0,type,ranges,opt)
  opt@lbLabelBarOn = True
add_reg(plot(4),ts2,type,ranges,opt)
  opt@lbLabelBarOn = True
  opt@Scale = 0.3
; add_reg_diff(plot(7),ts0,ts2,type,ranges,opt)
; add_diff(plot(7),type,year01,year2,ranges,opt)


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
  opt@cnLineThicknessF = 12
  opt@gsnContourNegLineDashPattern = 1
    ; opt@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  opt@cnLineColors = (/"#1B71B6","#2392C9","#28A0CE","#4EC0D9","#F28D75","#EE6B54","#EA463B","#E82229"/)
  ; opt@cnLineColors = (/"#1B71B6","#2392C9","#28A0CE","#4EC0D9","#F28D75","#EE6B54","#EA463B","#b44711"/)
  ; opt@cnLineColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLevels := (/-5,-4,-3,-2,2,3,4,5/)
  ; opt@cnMonoLineColor = True
  opt@test = False
  ; opt@lbLabelBarOn = True
; add_reg(plot(5),ESWJ0,type,ranges,opt)
;# 复合事件
type = "CE"
ts_CE01 := dim_standardize_Wrap(ts0({ispan(1982, 1998, 1)}), 0)
ts_CE2 := dim_standardize_Wrap(ts2({ispan(1999, 2021, 1)}), 0)
  ; opt@mode = "hatching"
  opt@cnFillOn = False
  opt@cnLinesOn = False
  opt@cnFillScaleF = 1.
  opt@cnFillDotSizeF = 0.0035
  opt@test = True
  opt@testSmooth = True
  opt@cnLineThicknessF = 4
  ; opt@cnLineColor = "Black"
; opt@stipplingColor = "#fdcc38"
  opt@stipplingColor = "white"
  opt@lbBoxSeparatorLinesOn = False
  opt@mode = "contour"
  ; opt@cnLineColors = (/"#229bff","#229bff","#229bff","#229bff","#F28D75","#EE6B54","#EA463B","#E82229"/)
  opt@cnLineColors := (/"Black","Black","Black","Black"/)

add_reg(plot(0),ts_CE01,type,ranges,opt)
add_reg(plot(3),ts_CE2,type,ranges,opt)

; add_reg(plot(1),ts_CE01,type,ranges,opt)
; add_reg(plot(4),ts_CE2,type,ranges,opt)


;# fig.3c,f,i 降水
;GPCP只能从1979开始
ts1 := EWJA1
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
  ; opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#A2742A"/)
  opt@cnLevels = (/-5,-4,-3,-2,-1,1,2,3,4,5/)
; delete(opt@cnFillColors)
; delete(opt@cnLevels)
; add_cor(plot(7),ts,type,ranges,opt)
; ranges(0) = 20
  type@range(0) = -20
  ; opt@mode = "hatching"
  ; opt@hatchingPattern = 8
  ; opt@cnFillScaleF = 0.5
  ; opt@hatchingColor = "White"
  opt@test = True
  opt@cnFillDotSizeF = 0.003
  opt@cnFillScaleF = 0.95
  opt@cnFillDotOpacityF = 0.8
  opt@lbBoxSeparatorLinesOn = False
  opt@lbLabelBarOn = False
  opt@mode = "hatching"

; print(ranges)
add_reg(plot(2),ts1,type,ranges,opt)
  ; opt@lbLabelBarOn = True
add_reg(plot(5),ts2,type,ranges,opt)
  ; opt@lbLabelBarOn = True
; add_reg_diff(plot(8),ts1,ts2,type,ranges,opt)

; add_diff(plot(8),type,year1,year2,ranges,opt)

;# 尝试土壤湿度
; ts3 = dim_standardize_Wrap(ESWJ({ispan(1959, 1998, 1)}), 0)
; type = "SWV1"
;   type@source = "ERA5_LAND"
;   opt@Scale = 0.003
;   opt@smoothing = True
; add_reg(plot(2),ts3,type,ranges,opt)
; add_reg(plot(5),ts2,type,ranges,opt)
;   opt@lbLabelBarOn = True
;   opt@pmLabelBarWidthF = 0.5
;   opt@pmLabelBarHeightF = 0.1
;   opt@pmLabelBarOrthogonalPosF = 0.1
;   opt@lbTitleString = "Soil Moisture (m~S~3~N~ m~S~-3~N~)"
;   opt@lbTitleFontHeightF = 0.025
;   opt@lbTitlePosition = "Bottom"
;   opt@lbTitleDirection = "Across"
; add_reg_diff(plot(8),ts3,ts2,type,ranges,opt)

type = "precip"
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
  opt@lbLabelBarOn = False

add_reg(plot(2),ts0,type,ranges,opt)
  opt@lbLabelBarOn = True
add_reg(plot(5),ts2,type,ranges,opt)
  opt@lbLabelBarOn = True
  opt@pmLabelBarOrthogonalPosF = 0.1
  opt@cnFillOn = True
  opt@cnLinesOn = False
; add_reg_diff(plot(8),ts0,ts2,type,ranges,opt)
; add_diff(plot(8),type,year01,year2,ranges,opt)
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
    rvc@vcRefAnnoOrthogonalPosF = -1.15
    rvc@vcRefAnnoFontHeightF = 0.02
    rvc@vcRefAnnoPerimOn = False
    rvc@vcLineArrowColor = "DodgerBlue"
  ; add_reg_vc(plot(2),ts0,type_vc,range,rvc)
  ; add_reg_vc(plot(5),ts2,type_vc,range,rvc)

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#686868"
  res_topo@cnLineThicknessF = 5.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
range(2) = 40
add_topo(plot(0),range,3000,res_topo)
add_topo(plot(1),range,3000,res_topo)
add_topo(plot(2),range,3000,res_topo)
add_topo(plot(3),range,3000,res_topo)
add_topo(plot(4),range,3000,res_topo)
add_topo(plot(5),range,3000,res_topo)
; add_topo(plot(6),range,3000,res_topo)
; add_topo(plot(7),range,3000,res_topo)
; add_topo(plot(8),range,3000,res_topo)
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
  add_line(plot(0),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(1),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(2),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(3),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(4),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(5),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(6),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(7),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(8),lat_JA_new&lon,lat_JA_new,line)
;# 组图
resp := True
  resp@gsnFrame = False
  ; resp@gsnPanelScalePlotIndex = 1
  ; resp@gsnPanelYWhiteSpacePercent = 5.
  resp@gsnPanelXWhiteSpacePercent = 5.
  ; resp@gsnPanelRowSpec = True
  resp@gsnPanelXF = (/0.04,0.38,0.71,0.04,0.38,0.71,0.03,0.37,0.71/)
  resp@gsnPanelYF = (/0.9,0.9,0.9,0.65,0.65,0.65,0.33,0.33,0.33/)
  ; resp@gsnPanelScaleF = (/0.3,0.3,0.3,0.3/)
  resp@gsnMaximize = False
  ; resp@gsnPanelLeft = -0.1
  ; resp@gsnPanelDebug = True
  ; resp@gsnPanelGridYF = 0.4
gsn_panel(wks,plot,(/3,3/),resp)


frame(wks)
; delete(wks)
show(fileName+".png")
end