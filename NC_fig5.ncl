begin ;记录全局参数
  ; start_time = get_cpu_time()
  pwd = systemfunc("pwd")
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
    fig@wkPaperWidthF = 25
    fig@wkPaperHeightF = 25
  png = "png"
    png@wkHeight = 2000
    png@wkWidth = 2000
;# fileName
itemType = "Nature"
fileName = "NC_fig5"
fig2png = "png"
  fig2png@wkHeight = 4096
  fig2png@wkWidth = 4096
wks := gsn_open_wks(fig,fileName)
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
print(ESWJ)
  type@range = rangeWAJ
U200 := process(type,method)
WAJ_index := calcJetAxisStrength(U200)
  type@range = rangeEAJ
U200 := process(type,method)
EAJ_index := calcJetAxisStrength(U200)

;# 投影指数
f = addfile("ESWJ_index.nc", "r")
EWJA = f->EWJA
EWJA01 = dim_standardize_Wrap(EWJA({year01}), 0)
EWJA1 = dim_standardize_Wrap(EWJA({year1}), 0)
EWJA2 = dim_standardize_Wrap(EWJA({year2}), 0)

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

ts0 = EWJA01
ts1 = EWJA2


;# Fig.5A底图
size := 3
  size@gsnLeftString = (/genItem("A",itemType)+"  CGSR Teleconnection",genItem("B",itemType)+"   SST (Mar,Apr)",genItem("C",itemType)+"   SST (May,Jun)"/)
  size@gsnLeftStringParallelPosF = 0
  size@gsnLeftStringFontHeightF = 0.03
  size@gsnLeftStringOrthogonalPosF = 0.02
  ; size@gsnRightString = "1 m~S~-2~N~ s~S~-2~N~"
  ; size@gsnRightStringFontHeightF = 0.02
  ; size@gsnRightStringOrthogonalPosF = -0.03
  ; size@gsnRightStringParallelPosF = 0.98
  size@gsnMaskLambertConformal = True
  size@mpGridAndLimbOn = False
  size@mpGridLatSpacingF = 65
  size@mpGridMaxLatF = 85
  size@mpGridLonSpacingF = 30
  size@mpGridLineDashPattern := 2
  size@vpHeightF = 0.83
  size@vpWidthF = 0.95
  size@polar = True
  size@mpCenterLonF = 90
  size@gsnPolarLabelFontHeightF = 0.02
  size@gsnPolarLabelSpacing = 120
  size@gsnPolarLabelDistance = 1.01
  ; size@gsnPolarTime = True
  size@mpLandFillColor = "White"
  size@mpGeophysicalLineThicknessF = 0.2
; range = (/10,85,-30,180/)
range = (/25,85,-100,40/)
plot := plot_bases(wks,range,size)

;# fig.5B 底图
; ts0 := ESWJ0
ranges := (/0,70,180,350/)
opt := True
notDrawAndFrame(opt)
  opt@vpHeightF = 0.57
  opt@vpWidthF = 0.53
  opt@tmYLLabelsOn = True
  ; opt@gsnLeftString = (/"EOF1 "+min(year0)+"-"+max(year0),min(year1)+"-"+max(year1),min(year2)+"-"+max(year2)/)
  opt@gsnLeftStringParallelPosF = 0
  opt@gsnLeftString = "NET-Heatwave & SPEI~C~ "+genItem("B",itemType)
  opt@gsnLeftStringFontHeightF = 0.034
  opt@gsnLeftStringOrthogonalPosF = -0.08

  opt@gsnCenterStringFontHeightF = 0.045
  opt@gsnCenterStringOrthogonalPosF = 0.17
  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 35.
  opt@mpLandFillColor = "transparent"
  opt@mpCenterLonF = 260
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 80
  opt@mpMinLatF = 10
  opt@mpMaxLonF = 290
  opt@mpMinLonF = 225
  opt@mpGridAndLimbOn = True
  opt@mpGridLineThicknessF = 0.5
  opt@mpGridLineColor = "DimGray"
  opt@mpGridLonSpacingF = 30
  opt@mpGridLatSpacingF = 15
  ; opt@mpGridLineDashPattern = 1
  opt@mpGeophysicalLineColor = "#206e22"
  opt@mpGeophysicalLineThicknessF = 0.3
  opt@mpPerimOn         = True 
  opt@mpPerimDrawOrder = "PostDraw"
  ; opt@mpPerimLineThicknessF = 5
  opt@mpOceanFillColor = "White"
  opt@mpFillDrawOrder = "PostDraw"

plot(1) = plot_base(wks,ranges,opt)

;# fig.5C 底图
opt := True
notDrawAndFrame(opt)
  opt@gsnLeftString = "Northeastern Atlantic SST~C~ "+genItem("C",itemType)
  opt@gsnLeftStringFontHeightF = 0.034
  opt@gsnLeftStringParallelPosF = 0
  opt@gsnLeftStringOrthogonalPosF = -0.08
  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 50.
  ; opt@mpLandFillColor = "transparent"
  opt@mpCenterLonF = 0
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 82
  opt@mpMinLatF = 34
  opt@mpMaxLonF = -15
  opt@mpMinLonF = 20
  opt@vpHeightF = 0.57
  opt@vpWidthF = 0.53
  opt@tmXBLabelFontHeightF = 0.02
  opt@tmYLLabelFontHeightF = 0.02
  opt@tmXBMajorLengthF = 0.01
  opt@tmXBMajorOutwardLengthF = 0.01
  opt@tmXBLabelDeltaF = -0.7
  ; opt@tmBorderThicknessF = 10  
  opt@mpGridAndLimbOn = True
  opt@mpGridLineThicknessF = 0.5
  opt@mpGridLineColor = "DimGray"
  opt@mpGeophysicalLineThicknessF = 0.3
  opt@mpGridLonSpacingF = 30
  opt@mpGridLatSpacingF = 15
  opt@mpPerimOn         = True 
  opt@mpPerimDrawOrder = "PostDraw"

  ; opt@tmXBBorderOn = True
plot(2) = plot_base(wks,(/32,83,-25,32/),opt)
;# Fig5A H300
type = "h"
  type@source = "ERA5"
  type@range := (/25,85,0,360/)
  type@level = 300
  type@month = (/7,8/)
opt := True
notDrawAndFrame(opt)
  opt@Scale = 5.
  opt@lbLabelFormat = "%0.0f"
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleDirection = "Across"
  opt@lbOrientation = "Horizontal"
  opt@lbTitleString = "Geopotential Height (gpm)"
  opt@lbTitleAngleF = 0
  opt@lbTitleFontHeightF = 0.018
  opt@lbTitleOffsetF = 0.3
  opt@lbLabelFontHeightF = 0.018
  opt@lbBoxSeparatorLinesOn = False
  opt@pmLabelBarHeightF = 0.06
  opt@pmLabelBarWidthF = 0.5
  opt@pmLabelBarOrthogonalPosF = 0.08
  opt@mode = "hatching"
  opt@hatchingPattern = 6
  opt@hatchingColor = "white"
  opt@hatchingRepeat = 50
  opt@gsnAddCyclic = True
  opt@cnFillScaleF = 1.2
  ; opt@cnLinesOn = True
  ; opt@cnLineColor = "White"
  ; opt@cnLineThicknessF = 5
add_reg(plot(0),ts1,type,range,opt)
;# 画经向风
type = "v"
  type@source = "jra55"
  opt@Scale = 0.5
  opt@lbLabelFormat = "%0.1f"
  opt@lbTitleString = "Meridional Wind (m s~S~-1~N~)"
  opt@cnFillOn = False
  opt@cnLinesOn = True
  opt@smoothing = True
  opt@test = False
  ; opt@gsnContourNegLineDashPattern = 11
  opt@cnLineThicknessF = 8
  opt@cnLineColors = (/"#0066ff","#0066ff","#0066ff","#0066ff","Firebrick1","Firebrick1","Firebrick1","Firebrick1"/)
  type@range = (/0,62,0,360/)
add_reg(plot(0),ts1,type,range,opt)

;# 加波活动通量
  type@source = "jra55"
  type@range(0) = 27
  type@range(1) = 60
  ; type@range(2) = range(2)-10
  ; type@range(3) = range(3)+10
  ; opt@vcLineArrowColor = "Firebrick1"
  opt@vcLineArrowColor = "Magenta1"
  opt@vcRefAnnoPerimOn = False
  opt@vcRefAnnoString1On = False
  opt@vcRefAnnoString2On = True
  opt@vcRefAnnoString2 = "1 m~S~-2~N~ s~S~-2~N~"
  opt@vcRefAnnoFontHeightF = 0.015
  opt@vcRefMagnitudeF = 1.0
  opt@vcRefLengthF = 0.08
  opt@vcRefAnnoParallelPosF = 1.
  opt@vcRefAnnoOrthogonalPosF = -0.3
  opt@vcMaxMagnitudeF = 2
  opt@vcMinMagnitudeF = 0.1
  opt@vcLineArrowThicknessF = 5
  opt@vcLineArrowHeadMaxSizeF = 0.05
  opt@vcLineArrowHeadMinSizeF = 0.005
  opt@gsnAddCyclic = True

add_waf_dev(plot(0),ts1,type,range,opt)

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 3.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
add_topo(plot(0),(/10,50,40,120/),3000,res_topo)

res_line := True
  res_line@gsLineThicknessF = 2
add_line(plot(0),(/0,180,360/),(/85,85,85/),res_line)
add_line(plot(0),(/0,180,360/),(/25,25,25/),res_line)
;# fig5B 热浪
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
  opt@lbLabelFontHeightF = 0.035
  opt@lbBoxSeparatorLinesOn = False
  opt@pmLabelBarHeightF = 0.6
  opt@pmLabelBarWidthF = 0.065
  opt@pmLabelBarOrthogonalPosF = 0.06
  opt@pmLabelBarParallelPosF = 0.49
  opt@lbTitleString = "Heatwave (days month~S~-1~N~)"
  opt@lbTitleAngleF = -90
  opt@lbTitleOffsetF = 0.4
  opt@lbTitlePosition = "Right"
  opt@lbTitleDirection = "Across"
  opt@lbTitleFontHeightF = 0.035
  opt@lbOrientation = "Vertical"
  opt@smoothing = True
  ; opt@cnFillColors := (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnLevels := (/-6,-5,-4,-3,-2.5,-2,-1.5,-1,1,1.5,2,2.5,3,4,5,6/)
  ; opt@cnFillColors = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#f17c22","#ff0000","#b02418"/)
  ; ; opt@cnFillColors := (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnLevels := (/-7,-5,-3,-1,1,3,5,7,9/)
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  ; opt@cnLevels = (/-3,-2,-1.5,-1,-0.5,0.5,1,1.5,2,3/)*2
  ; opt@cnLevels = (/-2.5,-2,-1.5,-1,-0.5,0.5,1,1.5,2,2.5/)*2
  opt@cnLevels = (/-2.5,-2,-1.5,-1,-0.5,0,0.5,1,1.5,2,2.5/)*2
  ; opt@cnLevels = (/-3,-2.5,-2,-1.5,-1,1,1.5,2,2.5,3/)*2
  opt@lbLabelStride = 2
    opt@cnFillDotSizeF = 0.0035
  opt@stipplingColor = "white"
  ; opt@cnFillPattern
  opt@mode = "stippling"
  opt@hatchingPattern = 6
  opt@hatchingColor = "Grey90"
  ; opt@hatchingColor = "#dadada"
  ; opt@hatchingColor = "white"
  opt@hatchingRepeat = 50
  opt@cnFillScaleF = 0.8
  ; opt@cnFillScales = (/0.5,0.5,0.5,0.5,0.5/)
  opt@cnLineThicknessF = 10
  opt@lbLabelBarOn = True
  ; opt@cnfill
  ; opt@cnFillOpacityF = 0.1
add_reg(plot(1),ts1,type,ranges,opt)


ts2 = dim_standardize_Wrap(ESWJ({ispan(1999, 2021, 1)}), 0)
;# fig.5B SPEI
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
  opt@lbLabelBarOn = False
  opt@cnFillColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FFFFFF","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLineColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#CCE6C7","#FEF5C7","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLineColors = (/"Black","Black","Black","Black","Black","Black","Black","Black","Black","Black"/)
  positiveColor = "#6a2100"
  opt@cnLineColors = (/"#2d8134","#2d8134","#2d8134","#2d8134","#2d8134",positiveColor,positiveColor,positiveColor,positiveColor,positiveColor/)
  opt@cnMonoLineColor = True
  ; opt@gsnContourNegLineDashPattern = 12
  opt@cnLineColor = "Black"
  opt@cnLevels = (/-3,-2.5,-1.9,-1.3,-0.7,0.7,1.3,1.9,2.5,3/)*2
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
  opt@test = True
  opt@cnFillOn = False
  opt@cnLinesOn = True
  opt@cnLineThicknessF = 4
  opt@cnLineColor = "DimGray"
  opt@mode = "hatching"
  opt@hatchingPattern = 6
  opt@hatchingRepeat = 50
  opt@hatchingColor = "#000000"
; add_cor(plot(0),Jet1,type,ranges,opt)
  type@range(0) = 25
  type@range(3) = 300
add_reg(plot(1),ts2,type,ranges,opt)


;# 复合事件
type = "CE"
  ts_CE2 := dim_standardize_Wrap(ts1({ispan(1999, 2021, 1)}), 0)
  type@source =  "ncep2"
  opt@mode = "stippling"
  opt@cnFillOn = False
  opt@cnLinesOn = False
  opt@cnFillScaleF = 1.
  opt@cnFillDotSizeF = 0.0035
  opt@test = True
  opt@testSmooth = True
  opt@cnLineThicknessF = 10
; opt@stipplingColor = "#fdcc38"
  opt@stipplingColor = "white"
  opt@lbBoxSeparatorLinesOn = False
  ; opt@mode = "contour"
  ; opt@cnLineColors := (/"#F28D75","#00aaff","#00aaff","#E82229"/)

; add_reg(plot(1),ts_CE2,type,ranges,opt)

;# fig5C
type := "sst"
  type@source = "ERA5"
  type@month := (/2/)
  type@level = 700
opt := True
notDrawAndFrame(opt)
  opt@smoothing = True
  opt@Scale = 0.05
  opt@lbLabelFormat = "%0.2f"
  opt@lbTitleString = "Correlation"
  opt@lbTitleFontHeightF = 0.035
  opt@lbLabelFontHeightF = 0.034
  opt@lbLabelAngleF = -80
  opt@lbTitleOffsetF = 0.4
  opt@lbLabelStride = 1
  opt@gsnLeftStringOrthogonalPosF = 0.03
  opt@pmLabelBarWidthF = 0.065
  opt@pmLabelBarHeightF = 0.6
  opt@pmLabelBarOrthogonalPosF = 0.06
  opt@lbOrientation = "Vertical"
  opt@lbTitlePosition = "Right"
  opt@lbTitleDirection = "Across"
  opt@lbTitleAngleF = -90
  opt@lbBoxSeparatorLinesOn = False
  opt@lbLabelBarOn = True
  opt@gsnAddCyclic = True
  opt@cnFillDrawOrder = "PreDraw"
  opt@test = False
  t = t_value(dimsizes(year2)-2)
  opt@cnFillColors := (/"#C1E0B8","#FFFFFF","#F6E9BC","#F0BF2A","#A57E1E"/)
  opt@cnLevels := (/-t@r90,t@r90,0.45,0.55/)
  type@range = (/0,90,0,360/)
  range(0) = 0
; add_reg(plot(0),ts1,type,range,opt)
; add_cor(plot(0),ts1,type,range,opt)
  type@month := (/7,8/)
add_cor(plot(2),ts1,type,range,opt)
  opt@cnLevels := (/-4,-3,-2,-1,1,2,3,4/)
  opt@cnFillOn = False
  opt@cnLinesOn = True
  opt@Scale = 0.2
; add_reg(plot(2),ts1,type,range,opt)
  ; type@month := (/5,6/)
; add_reg(plot(2),ts1,type,range,opt)
; add_cor(plot(2),ts1,type,range,opt)
; add_cor(plot(2),ts1,type,range,opt)

; type = "lwa"
; add_cor(plot(2),ts1,type,range,opt)

rlable := True
  rlable@lat_spacing = 5
  rlable@tmYLLabelsOn = False
  rlable@tmYLOn = False
  rlable@lon_spacing = 30
  rlable@txFontHeightF = 0.013
  range(0) = 20
  ; rlable@txAngleF = 0
  ; print(range)
; add_lc_labels(plot(0),range,rlable)
; add_lc_labels(plot(2),range,rlable)
; add_lc_labels(plot(2),range,rlable)

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
  ; add_line(plot(0),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(2),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(6),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(7),lat_JA_new&lon,lat_JA_new,line)

resp = True
  resp@gsnPanelLabelBar = False
  resp@lbOrientation = "Vertical"
  ; resp@lbTitleString = "SST (K)"
  resp@lbTitleString = "Correlation"
  resp@lbTitlePosition = "Right"
  resp@lbTitleDirection = "Across"
  resp@lbTitleAngleF = 90
  resp@pmLabelBarHeightF = 0.5
  resp@pmLabelBarWidthF = 0.07
  resp@pmLabelBarOrthogonalPosF = 0.05
  resp@lbTitleFontHeightF = 0.015
  resp@lbTitleOffsetF = 0.3
  resp@lbLabelFontHeightF = 0.015
  resp@gsnPanelScaleF = (/0.7,0.52,0.52/)
  ; resp@gsnPanelYF = (/0.95,0.9/)
  ; resp@gsnPanelXF = (/0.04,0.6/)
  resp@gsnPanelYF = (/0.96,0.969,0.6/)
  resp@gsnPanelXF = (/0.02,0.64,0.64/)
  resp@gsnMaximize = True
  ; resp@wkOrientation = "landscape"
  resp@gsnPaperOrientation = "portrait"
  ; resp@gsnPanelYWhiteSpacePercent = 5.
gsn_panel(wks,plot,(/1,3/),resp)
delete(wks)
system("gs -q -sDEVICE=png16m -sBATCH -sOutputFile="+fileName+".png -dNOPAUSE -r200 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "+fileName+".pdf")
show(fileName+".png")
end