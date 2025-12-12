begin ;记录全局参数
  localpath := (/"/SSD1/","/SSD1/","/SSD1/","/home/llf/code/ncl/","/data/"/)
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

undef("r2pStringDev")
function r2pStringDev(r,df)
local p
begin
  p = R2p(r,df)
  if(p .ge. 0.01)then
    return "p = "+sprintf("%.2f",p)
  end if
  if(p .eq. 0)then
    return "p = 0"
  end if
  multi_level = abs(toint(log10(p)))+1
  return "p = "+sprintf("%.1f",p*10^multi_level)+"~F34~4~F21~10~S~-"+multi_level+"~N~"
end

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
  ; print(data_std)
  upper = data_mean+0.5*data_std
  lower = data_mean-0.5*data_std
  copy_VarCoords(data_mean, upper)
  copy_VarCoords(data_mean, lower)
  addShading(plotid,upper,lower,opt)
end

undef("newBoldHolyCircle")
function newBoldHolyCircle(wks)
local mstring,fontnum,xoffset,ratio,size,angle,new_index
begin
mstring = "o"
  fontnum = 22
  xoffset = 0.0
  yoffset = 0.0
  ratio   = 0.9
  size    = 1.5
  angle   = 0.0
  new_index = NhlNewMarker(wks, mstring, fontnum, xoffset, yoffset, ratio, size, angle)
  return new_index
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

begin
  ;部分参数
  test0 = True
    test0@folder = "test0/"
    test0@rangeWAJ = (/20, 70, 40, 80./)
    test0@rangeEAJ = (/20, 70, 90, 123./)
    test0@window = 21

  test1 = True
    test1@folder = "test1/"
    test1@rangeWAJ = (/20, 70, 40, 80./)
    test1@rangeEAJ = (/20, 70, 90, 130./)
    test1@window = 21

  test2 = True
    test2@folder = "test2/"
    test2@rangeWAJ = (/20, 70, 40, 85./)
    test2@rangeEAJ = (/20, 70, 90, 130./)
    test2@window = 21

  test3 = True
    test3@folder = "test3/"
    test3@rangeWAJ = (/20, 70, 40, 80./)
    test3@rangeEAJ = (/20, 70, 90, 135./)
    test3@window = 21

  test4 = True
    test4@folder = "test4/"
    test4@rangeWAJ = (/20, 70, 40, 85./)
    test4@rangeEAJ = (/20, 70, 90, 135./)
    test4@window = 21

  test5 = True
    test5@folder = "test5/"
    test5@rangeWAJ = (/20, 70, 40, 85./)
    test5@rangeEAJ = (/20, 70, 90, 140./)
    test5@window = 21

  test6 = True
    test6@folder = "test6/"
    test6@rangeWAJ = (/20, 70, 35, 85./)
    test6@rangeEAJ = (/20, 70, 90, 140./)
    test6@window = 21

test7 = True
  test7@folder = "test7/"
  test7@rangeWAJ = (/20, 70, 40, 80./)
  test7@rangeEAJ = (/20, 70, 90, 123./)
  test7@window = 27
test = test0

  folder = test@folder ;"EAJ_plot"
  window = test@window
  ; window = 27
  rangeWAJ = test@rangeWAJ
  rangeEAJ = test@rangeEAJ

  setBufferPath(localpath(3)+".buffer/")
  bufferMode = "disabled"
  ; bufferMode = "smart"
  pdf = "pdf"
    pdf@wkPaperWidthF = 20
    pdf@wkPaperHeightF = 20
  png = "png"
    png@wkHeight = 2000
    png@wkWidth = 2000
  year := ispan(1958, 2022, 1)
  year0 := ispan(1958, 1978, 1)
  year1 := ispan(1979, 1998, 1)
  year2 := ispan(1999, 2022, 1)
  year01 := ispan(1958, 1998, 1)
  month = (/7,8/)
  setDim(year,0,"year",year)
  setDim(year0,0,"year",year0)
  setDim(year1,0,"year",year1)
  WNPSH_level = 5870
  SAH_level = 14360
;# ESWJ指数(急流轴强度)
type := "u"
  type@source = "ERA5"
  type@month := (/7,8/)
  type@year := ispan(1940, 2022, 1)
  type@level = 200
  type@range = (/10,80,-12.5,191/)
method := "stddev"
  method@detrend = False
  ; type@range = (/20,60,30,155/)
  type@range = (/20,60,30,145/)
U200_sd := process(type,method)
method := "mean"
  method@detrend = False
  type@range := (/20, 70, 23, 123./)
  type@year := year
U200 := process(type,method)
  type@range = rangeWAJ
U200 := process(type,method)
WAJ_index := calcJetAxisStrength(U200)
  type@range = rangeEAJ
U200 := process(type,method)
EAJ_index := calcJetAxisStrength(U200)

WAJ_minus_EAJ := WAJ_index - EAJ_index
WAJ_plus_EAJ := WAJ_index + EAJ_index
copy_VarCoords(WAJ_index, WAJ_minus_EAJ)
copy_VarCoords(WAJ_index, WAJ_plus_EAJ)
; print(run_cor(WAJ_index, EAJ_index, window))
; exit()
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

;# 各套数据的急流轴强度指数及滑动相关
type := "u"
  type@source = "era5"
  type@month := (/7,8/)
  type@year := ispan(1940, 2022, 1)
  type@level = 200
  type@range := rangeEAJ
method := "mean"

cor_ERA5 = readCor(folder+"cor_ERA5.nc")
; window = 21
; rangeWAJ := (/20, 70, 40, 80./)
; rangeEAJ := (/20, 70, 90, 123./)
; type := "u"
;   type@source = "era5"
;   type@month := (/7,8/)
;   type@year := ispan(1940, 2022, 1)
;   type@level = 200
;   type@range := rangeEAJ
; method := "mean"
; cor_ERA5 := calcRunCorEAJWAJ(type,rangeEAJ,rangeWAJ,window)
cor_ncep2 = readCor(folder+"cor_ncep2.nc")
cor_ncep1 = readCor(folder+"cor_ncep1.nc")
cor_erai = readCor(folder+"cor_erai.nc")
cor_jra55 = readCor(folder+"cor_jra55.nc")
cor_cfs = readCor(folder+"cor_cfs.nc")
cor_20thCRv3 = readCor(folder+"cor_20thcrv3_members.nc")
cor_20thCRv3_mean = dim_avg_n_Wrap(cor_20thCRv3, 0)
; cor_era20c = readCor("cor_era20c.nc")
cor_era20c = readCor(folder+"cor_20c_40.nc")
cor_cera20c = readCor(folder+"cor_cera20c.nc")
cor_cera20c_mean = dim_avg_n_Wrap(cor_cera20c, 0)

year_all = ispan(1900, 2022, 1)

;# 画图（带EOF，3张图,另一套配色）
year := ispan(1958, 2022, 1)
year0 := ispan(1958, 1978, 1)
year1 := ispan(1979, 1998, 1)
year2 := ispan(1999, 2022, 1)
plot := newPlots(8)
fileName = folder+"NC_fig1"
wks := gsn_open_wks(pdf,fileName)
labelColor = "#434343"

;# Fig1C 下半部分
itemType = "Nature"
opt := True
t = t_value(window-2)
notDrawAndFrame(opt)
  opt@minmax = (/-0.35,0.85/)
  opt@vpWidthF = 1.525
  opt@vpHeightF = 0.55
  opt@gsnXYBarChart = False
  opt@extend = -9
  opt@xyLineThicknessF = 3.
  opt@gsnLeftString = "";genItem("c",itemType)
  opt@gsnLeftStringFontHeightF = 0.037
  ; opt@gsnLeftStringOrthogonalPosF = 0.05
  opt@gsnLeftStringOrthogonalPosF = -0.09
  opt@gsnLeftStringParallelPosF = -0.05
  opt@gsnRightString = ""
  opt@tiXAxisString = "Mid-year of "+window+"-yr sliding window"
  opt@tiXAxisFontHeightF = 0.025
  opt@tiXAxisOffsetYF = 0.07
  opt@tiXAxisFontColor = "Grey29"
  opt@tmYLValues = (/-0.3,0,0.3,0.6,0.8/)
  opt@tmYLLabelFontHeightF = 0.03
  opt@tmYLLabelFontColor = labelColor
  opt@tmXBLabelFontHeightF = 0.03
  opt@tmXBLabelFontColor = labelColor
  ; opt@tmXBLabelFont = 5
  opt@trXMinF = 1950
  opt@trXMaxF = 2015
  opt@tmXTBorderOn = False
  opt@tmYRBorderOn = False
  opt@tmYROn = True
  opt@tmYRMode = "Explicit"
  ; opt@tmYRValues = (/t@r95,t@r999/)
  opt@tmYRValues = (/t@r95/)
  opt@tmYRLabels = (/"95%","99%"/)
  opt@tmYRLabelsOn = True
  opt@tmYRLabelFontColor = "DimGray"
  opt@tmYRLabelFont = 22
  opt@tmYRLabelFontHeightF = 0.025
  opt@tmYRLabelDeltaF = -1.55
  opt@tmYRMajorLineColor = "DodgerBlue"
  opt@tmYRMajorThicknessF = 5
  opt@tmYRMajorLineColor = "transparent"
  opt@xyLineColor = "#076483"
  ; opt@xyLineColor = "#8ab18a"
  opt@xyLineThicknessF = 2.
  opt@xyLineColor = "#8ab18a"
  ; opt@xyLineColor = "MediumPurple"

  opt@gsnYRefLineColor = "transparent"
  opt@Yref = -10;不显示
  opt@vpClipOn = False
  opt@tmXBLabelsOn = True
  ; opt@gsnYRefLine = -10
  ; opt@tmXTBorderOn = False
  ; opt@tmYLFormat = "0@;*.2f"
  opt@tmXBLabelDeltaF = -0.7
; plot(3) = plot_ts(wks,cor_era20c,opt)
plot(3) = plot_ts(wks,cor_20thCRv3_mean,opt)
res_line := True
  res_line@gsLineThicknessF = 5
  res_line@gsLineDashPattern = 16
  res_line@gsLineColor = "DimGray"
; add_line(plot(3),(/1993,1993/),(/-0.4,0.73/),res_line)

text = "1993"
  text@txFontColor = "DimGray"
  text@txFontHeightF = 0.026
; add_text(plot(3),text,1993,0.77)
;# Fig.1C 上半部分
  ; opt@gsnLeftStringParallelPosF = 0.2
  opt@gsnRightString = "~F22~Evolution of R (WJA, EJA)"
  opt@gsnRightStringFontHeightF = 0.035
  opt@gsnRightStringOrthogonalPosF = -0.125
  ; opt@gsnRightStringParallelPosF = 0.7
  opt@gsnRightStringParallelPosF = 0.4
  ; opt@gsnRightStringFontColor = "#222222"
  opt@gsnRightStringFontColor = "white"
  ; opt@gsnRightStringFontColor = "Black"
  opt@trXMinF = 1815
  opt@trXMaxF = 1949
  opt@tiXAxisString = "Mid-year of "+window+"-yr sliding window"
  opt@tiXAxisOffsetYF = 0.07
  opt@tmXBTickSpacingF = 20
  opt@tmXBTickStartF = 1820
  opt@gsnLeftString = genItem("c",itemType)
  opt@gsnLeftStringOrthogonalPosF = -0.05
  opt@minmax = (/-0.35,0.75/)
  opt@vpHeightF = 0.48
  ; opt@vpHeightF = 0.38
  opt@tmYROn = False
  opt@tmXBLabelsOn = True
  opt@tmXBLabelDeltaF = -0.7
  opt@tmYRBorderOn = False
  opt@tmYROn = True
  opt@tmYRMode = "Explicit"
  ; opt@tmYRValues = (/t@r95,t@r999/)
  opt@tmYRValues = (/t@r95/)
  opt@tmYRLabels = (/"95%","99%"/)
  opt@tmYRLabelsOn = True
  opt@tmYRLabelFontColor = "DimGray"
  opt@tmYRLabelFont = 22
  opt@tmYRLabelFontHeightF = 0.025
  opt@tmYRLabelDeltaF = -1.55
  opt@tmYRMajorLineColor = "DodgerBlue"
  opt@tmYRMajorThicknessF = 5
  opt@tmYRMajorLineColor = "transparent"
  opt@xyLineColor = "#076483"
  opt@xyLineThicknessF = 3.
plot(0) = plot_ts(wks,cor_era20c,opt)

;# 绿框
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
x := 0.255;最左端.加粗下
y := 0.646
; width := 0.21
width := 0.185
height := 0.02
polyXF := (/x-width,x-width,x+width,x+width,x-width/)
polyYF := (/y-height,y+height,y+height,y-height,y-height/)
gsn_polygon_ndc(wks, polyXF, polyYF, res_box)
x := 0.837;最左端.加粗下
y := 0.975
width := 0.102
height := 0.016
polyXF := (/x-width,x-width,x+width,x+width,x-width/)
polyYF := (/y-height,y+height,y+height,y-height,y-height/)
gsn_polygon_ndc(wks, polyXF, polyYF, res_box)

;# Fig1C阴影
pgres := (/-10,10,min(year2)-0.5,2019/)
  pgres@gsFillOpacityF = 0.1
  pgres@gsFillColor = "#ff8747"
add_fillBox(plot(3),pgres)

  opt@xyLineThicknessF = 2.
  opt@xyLineColor = "#8ab18a"
; add_ts(plot(3),cor_20thCRv3_mean,opt)
add_ts(plot(0),cor_20thCRv3_mean,opt)
rshade := True
  ; rshade@gsFillColor = "MediumPurple"
  rshade@gsFillColor = "#8ab18a"
addSpreading(plot(0),cor_20thCRv3,rshade)
addSpreading(plot(3),cor_20thCRv3,rshade)

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
add_text(plot(0),line,1819,0.45)
add_text(plot(3),line,1954,0.625)

text := "R~S~2~N~ = 30%"
  text@txFontColor = "DodgerBlue"
  text@txFont = 22
  text@txFontHeightF = 0.025
add_string(plot(3),text,0.95,0.885)

  opt@xyLineColor = "MediumPurple"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 4
add_ts(plot(3),cor_cera20c_mean,opt)
add_ts(plot(0),cor_cera20c_mean,opt)
; add_ts(plot(0),cor_era20c,opt)
rshade := True
  ; rshade@gsFillColor = "MediumPurple"
  rshade@gsFillColor = "MediumPurple"
addSpreading(plot(0),cor_cera20c,rshade)
addSpreading(plot(3),cor_cera20c,rshade)
line = "CERA-20C"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1938,1943/),(/-0.4,-0.4/),line)
add_text(plot(0),line,1835,0.45)
add_text(plot(3),line,1962.5,0.625)
; add_text(plot(3),line,1989.5,-0.4)



tval := (/t@r95/);0.43
  tval@polyYRefDashPattern = 1
  tval@polyYRefMin = 1988
  tval@polyYRefMax = 2014
  tval@polyYRefColor = "DimGray"
add_Yref(plot(3),tval)
  tval@polyYRefMin = 1885
  tval@polyYRefMax := 1947.9
add_Yref(plot(0),tval)
tval := (/sqrt(0.3)/)
; tval := (/sqrt(0.5)/)
  tval@polyYRefDashPattern = 2
  ; tval@xyDashPattern
  tval@polyYRefMin = 1998
  tval@polyYRefMax := 2008
  tval@polyYRefColor = "DodgerBlue"
add_Yref(plot(3),tval)
line = "ERA-5"
  line@txFontColor = "Red"
  line@gsLineColor = "Red"

; add_line(plot(0),(/1912,1917/),(/0.75,0.75/),line)
add_text(plot(3),line,1952,0.77)

  ; opt@xyLineColor = "#3434ff"
  opt@xyLineColor = "DimGrey"
  opt@xyLineThicknessF = 10.
add_ts(plot(3),cor_ncep2,opt)
line = "NCEP/DOE-R2"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1912,1917/),(/0.55,0.55/),line)
add_text(plot(3),line,1971.5,0.77)
  opt@xyLineColor = "#f3a13c"
  opt@xyLineThicknessF = 7
line = "NCEP/NCAR-R1"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@yLineColor
; add_line(plot(0),(/1940,1945/),(/0.55,0.55/),line)
add_text(plot(3),line,1971.5,0.625)
add_ts(plot(3),cor_ncep1,opt)

  ; opt@xyLineColor = "Magenta"
  opt@xyLineColor = "#3434ff"

  opt@xyLineThicknessF = 7.
  opt@xyDashPattern = 0
add_ts(plot(3),cor_erai,opt)
  opt@xyLineThicknessF = 7.
line = "ERA-Interim"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern
; add_line(plot(0),(/1960,1965/),(/-0.4,-0.4/),line)
add_text(plot(3),line,1963,0.77)

  opt@xyLineColor = "#076483"
  opt@xyLineThicknessF = 3.
  opt@xyDashPattern = 0
; add_ts(plot(0),cor_era20c,opt)
line = "ERA-20C"
; line = "ERA-20C & ERA-40"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1965,1970/),(/-0.4,-0.4/),line)
add_text(plot(0),line,1853,0.45)
line = "ERA-20C (1950-1957) & ERA-40 (1958-2002)"
add_text(plot(3),line,1954,0.49)

text = "Strong UDZC period"
  text@txFontColor = "#ff5151"
  text@txFont = 21
  ; text@tx
add_text(plot(3),text,2007,0)
text = "R~S~2~N~ exceeding 30%"
add_text(plot(3),text,2007,-0.1)

;   opt@xyLineColor = "green"
;   opt@xyLineThicknessF = 7.
;   opt@xyDashPattern = 0
; line = "ERA-20CM"
;   line@gsLineColor = opt@xyLineColor
; add_line(plot(0),(/1965,1970/),(/-0.4,-0.4/),line)

opt@xyLineColor = "ForestGreen"
opt@xyLineThicknessF = 7.
  opt@xyDashPattern = 0
add_ts(plot(3),cor_jra55,opt)
line = "JRA-55"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern

; add_line(plot(0),(/1935,1940/),(/0.75,0.75/),line)
add_text(plot(3),line,1957,0.77)

  opt@xyLineColor = "Black"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 7.
  ; opt@xyDashPattern = 2
add_ts(plot(3),cor_cfs,opt)
line = "CFSR"
  line@txFontColor = opt@xyLineColor
  line@gsLineColor = opt@xyLineColor
  line@gsLineDashPattern = opt@xyDashPattern
; add_line(plot(0),(/1970,1975/),(/0.55,0.55/),line)
add_text(plot(3),line,1982,0.77)

  opt@xyLineColor = "Red"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 12
add_ts(plot(3),cor_ERA5,opt)
add_ts(plot(0),cor_ERA5,opt)

  opt@xyLineColor = "#076483"
  opt@xyDashPattern = 0
  opt@xyLineThicknessF = 5
add_ts(plot(3),cor_era20c,opt)

;# Fig1a 地球
opt := True
notDrawAndFrame(opt)
  opt@vpWidthF = 1.2
  opt@vpHeightF = 0.93
  opt@tmXBTickSpacingF = 40
  opt@tmYLTickSpacingF = 25
  opt@gsnLeftString = genItem("A",itemType)+ "  Jet Stream"
  opt@gsnLeftStringFontHeightF = 0.085
  opt@gsnLeftStringOrthogonalPosF = 0.02
  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 35.
  opt@mpLandFillColor = "#e9e9e9"
  opt@mpCenterLonF = 85
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 75
  opt@mpMinLatF = 0
  opt@mpMaxLonF = 150
  opt@mpMinLonF = 0

  opt@mpPerimOn         = False 
  opt@gsnMaximize = False
  opt@mpGeophysicalLineThicknessF = 0.5
  opt@mpGeophysicalLineColor = "transparent"
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
  type@year := year
; add_clim(plot(1),type,range,opt)
  opt@lbLabelFormat = "%0.1f"
  opt@lbLabelFontHeightF = 0.025
  opt@lbTitleString = "U200 (m s~S~-1~N~)"
  opt@lbTitleOffsetF = 0.2
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleDirection = "Across"
  opt@lbTitleFontHeightF = 0.025
  opt@lbTitleAngleF = 0
  opt@lbBoxLineThicknessF = 2
  opt@lbBoxLinesOn = True
  opt@lbBoxSeparatorLinesOn = False
  opt@pmLabelBarWidthF = 0.5
  opt@pmLabelBarHeightF = 0.1
  opt@pmLabelBarOrthogonalPosF = -0.05
  opt@pmLabelBarParallelPosF = 0.5
  opt@lbOrientation = "Horizontal"

  opt@cnLinesOn = False
  opt@cnLineThicknessF = 5.
  opt@cnLineDashPattern = 0
  opt@cnLevels := (/22,24,26,28,30,32/)
  ; opt@cnFillColors := (/"transparent","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  opt@cnFillColors := (/"transparent","#c3d9bb","#aecda4","#9ac392","#89bc86","#79b77a","#368237"/);,"#368237"/)
  opt@lbLabelStride = 2
  opt@lbLabelFormat = "%0.0f"
add_clim(plot(1),type,range,opt)
  opt@cnLinesOn = True
  opt@cnFillOn = False
  opt@cnLevels := (/3.5,4,4.5,5,5.5,6/)
  opt@cnLineColor = "#206e22"
  opt@cnLineThicknessF = 5
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
    line@gsLineColor = "#0082df"
    line@txJust = "BottomLeft"
    line@txFontColor = "#0082df"
  lat_JA_WAJ = lat_JA({rangeWAJ(2):rangeWAJ(3)})
  lat_JA_EAJ = lat_JA({rangeEAJ(2):rangeEAJ(3)})
  lat_JA_Center = lat_JA({rangeWAJ(3):rangeEAJ(2)})
  add_line(plot(1),lat_JA_WAJ&lon,lat_JA_WAJ,line)
    line@gsLineColor = "red"
    line@txFontColor = "red"
  add_line(plot(1),lat_JA_EAJ&lon,lat_JA_EAJ,line)
    line@gsLineColor = "white"
    line@gsLineThicknessF = 20
    line@txFontColor = "white"
  ; add_line(plot(1),lat_JA_Center&lon,lat_JA_Center,line)
box := (/0,90,rangeEAJ(2),rangeEAJ(3)/)
  box@gsLineThicknessF = 8.
  box@gsFillOpacityF = 0.2
  box@gsLineColor = "#0082df"
  box@gsFillColor = "#0082df"
; add_lineBox(plot(1),box)
; add_fillBox(plot(1),box)
box = (/0,90,rangeWAJ(2),rangeWAJ(3)/)
  box@gsLineColor = "#33a0ff"
  box@gsFillColor = "#33a0ff"
; add_lineBox(plot(1),box)
; add_fillBox(plot(1),box)
text := "WJA"
  text@txFontColor = "#0082df"
  text@txFontHeightF = 0.08
  text@txFont = 22
  text@txAngleF = -21
add_text(plot(1),text,60,31)
text = "EJA"
  text@txFontColor = "Red"
  text@txAngleF = 10
add_text(plot(1),text,105,30)


;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 5.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
range(2) = 40
add_topo(plot(1),range,3000,res_topo)


;# Fig1B
res_ts := True
notDrawAndFrame(res_ts)
  res_ts@minmax = (/-10,11/)
  res_ts@tmYRBorderOn = False
  res_ts@tmXTBorderOn = False
  res_ts@gsnXYBarChartColors = "red"
  res_ts@gsnLeftString = genItem("B",itemType)
  res_ts@gsnLeftStringParallelPosF = -0.09
  res_ts@gsnLeftStringOrthogonalPosF = 0.025
  res_ts@gsnLeftStringFontHeightF = 0.035
  R = escorc(EAJ_index({year2}), WAJ_index({year2}))
  df = dimsizes(year2)-2
  ; P = R2p(R,df)
  res_ts@gsnRightString = "~F22~R2 = "+sprintf("%.2f",R)+"~F21~, "+r2pStringDev(R,df)
  res_ts@gsnRightStringFontHeightF = 0.023
  res_ts@gsnRightStringFontColor = "White"
  res_ts@gsnRightStringParallelPosF = 0.99
  res_ts@gsnRightStringOrthogonalPosF = 0.01
  res_ts@tiXAxisString = "Year"
  res_ts@tiXAxisFontHeightF = 0.023
  res_ts@tiXAxisOffsetYF = 0.01
  res_ts@tiYAxisString = "m s~S~-1~N~"
  res_ts@tiYAxisFontHeightF = 0.023
  res_ts@tiYAxisOffsetXF = 0.025
  res_ts@vpHeightF = 0.38
  res_ts@vpWidthF = 0.915
  res_ts@tmXBLabelFontHeightF = 0.025
  res_ts@tmYLLabelFontHeightF = 0.025
  res_ts@tmYLLabels = (/"-7","0","7"/)
  res_ts@tmYLFormat = "%0.0f"
  ; res_ts@tmYLValues = (/-8,-4,0.0,4,8/)
  res_ts@tmYLValues = (/-7,0,7/)
  res_ts@trXMaxF = 2023
EAJ_index = dim_rmvmean_Wrap(EAJ_index)
; EAJ_index({year01}) = (/dim_rmvmean_Wrap(EAJ_index({year01}))/)
; EAJ_index({year2}) = (/dim_rmvmean_Wrap(EAJ_index({year2}))/)
plot(2) = plot_ts(wks,EAJ_index,res_ts)
nblc = newBoldHolyCircle(wks)
pgres := (/-10,11,1998.5,2023/)
  pgres@gsFillOpacityF = 0.1
  pgres@gsFillColor = "#ff8747"
add_fillBox(plot(2),pgres)
  res_ts@xyLineColor = "#0082df"
  ; res_ts@xyMarkLineMode = "Lines"
  res_ts@xyMarkLineMode = "Markers"
  res_ts@xyMarkers = nblc
  res_ts@xyMarkerSizeF = 0.013
WAJ_index = dim_rmvmean_Wrap(WAJ_index)
; WAJ_index({year01}) = (/dim_rmvmean_Wrap(WAJ_index({year01}))/)
; WAJ_index({year2}) = (/dim_rmvmean_Wrap(WAJ_index({year2}))/)
add_ts(plot(2),WAJ_index,res_ts)
  res_ts@xyMarkLineMode = "MarkLines"
  res_ts@xyLineColor = "#00a700"
  res_ts@xyLineThicknessF = 10
  res_ts@xyMarkers = 16
  res_ts@xyMarkerSizeF = 0.015
; WAJ_plus_EAJ = dim_standardize_Wrap(WAJ_plus_EAJ, 0)
; WAJ_plus_EAJ = (/WAJ_plus_EAJ*0.5/)
; WAJ_plus_EAJ = dim_rmvmean_Wrap(WAJ_plus_EAJ)

; add_ts(plot(2),WAJ_plus_EAJ,res_ts)

; WAJ_minus_EAJ = (/WAJ_minus_EAJ*0.5/)
WAJ_minus_EAJ = dim_rmvmean_Wrap(WAJ_minus_EAJ)

; add_ts(plot(2),WAJ_minus_EAJ,res_ts)


  ; res_ts@xyMarkLineMode = "Markers"
; add_ts(plot(2),WAJ_index({year2}),res_ts)

text := "WJA"
  text@txFontColor = "#0082df"
  text@txJust = "CenterLeft"
textY = 1.24
add_string(plot(2),text,-0.03,textY)
text = "&        Index, ERA-5"
  text@txFontColor = "Black"
add_string(plot(2),text,0.095,textY)
text = "EJA"
  text@txFontColor = "red"
add_string(plot(2),text,0.14,textY)
R = escorc(EAJ_index({year01}), WAJ_index({year01}))
P = R2p(R,dimsizes(year01)-2)
print(P)
text := "R1 = "+sprintf("%.2f",R)+", p = "+sprintf("%.2f", P)
  text@txFontHeightF = 0.025
  text@txJust = "CenterLeft"
add_text(plot(2),text,1968,9)
;# 组图
resp := True
  resp@gsnFrame = False
  resp@gsnPanelScalePlotIndex = 1
  resp@gsnPanelYWhiteSpacePercent = 5.
  resp@gsnPanelRowSpec = True
  resp@gsnPanelXF = (/0.07,0.025,0.39,0.07/)
  resp@gsnPanelYF = (/0.665,0.96,0.96,0.347/)
  resp@gsnPanelScaleF = (/0.57,0.25,0.6,0.57/)
  resp@gsnMaximize = True
  ; resp@gsnPanelLeft = -0.1
  ; resp@gsnPanelDebug = True
  ; resp@gsnPanelGridYF = 0.4
gsn_panel(wks,plot(0:3),(/4/),resp)


frame(wks)
delete(wks)
; print(fileName)
system("gs -q -sDEVICE=png16m -sBATCH -sOutputFile="+fileName+".png -dNOPAUSE -r200 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "+fileName+".pdf")
fullPath = "/home/llf/code/ncl/EurasianJet/UDZS_Code/"+fileName
show(fullPath)
end