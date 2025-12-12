begin ;记录全局参数
  localpath := (/"/SSD1/","/data/","/data/","/home/llf/code/ncl/"/)
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


begin
  ;部分参数
  folder = localpath(3)+"EurasianJet/Eurasian_figs/" ;"EAJ_plot"
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
  rangeWAJ = (/40, 47, 45, 85/)
  rangeEAJ = (/40, 47, 90, 130/)
  setDim(year,0,"year",year)
  setDim(year0,0,"year",year0)
  setDim(year1,0,"year",year1)
  setDim(year01,0,"year",year01)
  WNPSH_level = 5870
  ; SAH_level = 14360
  SAH_level = 12530
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
EWJA = f->EWJA_modified
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
ts1 := EWJA2
  ind_h1 := ind(ts1 .ge.  0.5)
  ind_l1 := ind(ts1 .le. -0.5)
ts0 := EWJA01
  ind_h0 := ind(ts0 .ge.  0.5)
  ind_l0 := ind(ts0 .le. -0.5)
; print(ESWJ2)
print(year2(ind_h1))
print(year2(ind_l1))
print(year01(ind_h0))
print(year01(ind_l0))
; print(ind_l1)
opt = True
ranges := (/10,50,10,120/)
range := (/0,50,100,190/)
type := "H"
type@level := 200
type@month := (/7,8/)
type@source = "era5"
type@range = ranges
opt@method = "clim"
type@year := ts1&year
SAH_clim1 := process(type,opt)
type@year := ts0&year
SAH_clim0 := process(type,opt)

type@level = 500
type@range = (/10,50,100,190/)
type@year := ts1&year
WNPSH_clim1 = process(type,opt)
type@year := ts0&year
WNPSH_clim0 = process(type,opt)

type_h := "H"
type_h@range = range
type_h@level = 500
type_h@month = (/7,8/)
type_h@source = type@source
type_h@year := ts1&year(ind_h1)
WPSH_h1 := process(type_h,opt)
type_h@year := ts0&year(ind_h0)
WPSH_h0 := process(type_h,opt)

type_l = "H"
type_l@range = range
type_l@level = 500
type_l@month = (/7,8/)
type_l@source = type@source
type_l@year := ts1&year(ind_l1)
WPSH_l1 := process(type_l,opt) 
type_l@year := ts0&year(ind_l0)
WPSH_l0 := process(type_l,opt) 

type_h@level = 200
type_h@range = (/00,80,20,130/)
type_h@year := ts1&year(ind_h1)
SAH_h1 := process(type_h,opt)
type_h@year := ts0&year(ind_h0)
SAH_h0 := process(type_h,opt)

type_l@level = 200
type_l@range = (/00,80,20,130/)
type_l@year := ts1&year(ind_l1)
SAH_l1 := process(type_l,opt)
type_l@year := ts0&year(ind_l0)
SAH_l0 := process(type_l,opt)

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

year_all = ispan(1900, 2022, 1)

;# 画图（带EOF，3张图,另一套配色）
year := ispan(1958, 2022, 1)
year0 := ispan(1958, 1978, 1)
year1 := ispan(1979, 1998, 1)
year2 := ispan(1999, 2022, 1)
plot := newPlots(8)
fileName = "NC_fig4"
wks := gsn_open_wks(pdf,fileName)
labelColor = "#434343"

;# Fig1a
itemType = "Nature"

;# 创建plot
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
  opt@mpGeophysicalLineColor = "#78CFD5"
  ; opt@mpGeophysicalLineThicknessF = 3
range := (/10,80,-12.5,191/)

plot(1) = plot_base(wks,range,opt)


ts0 := EWJA01
ts1 := EWJA2
ranges := (/0,75,0,190/)
opt := True
notDrawAndFrame(opt)
  opt@vpHeightF = 0.55
  opt@vpWidthF = 0.85
  opt@tmYLLabelsOn = True
  ; opt@gsnLeftString = (/"EOF1 "+min(year0)+"-"+max(year0),min(year1)+"-"+max(year1),min(year2)+"-"+max(year2)/)
  opt@gsnLeftStringFontHeightF = 0.045
  opt@gsnLeftStringParallelPosF = 0.05
  opt@gsnLeftStringOrthogonalPosF = -0.08
  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 35.
  opt@mpLandFillColor = "transparent"
  opt@mpCenterLonF = 85
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 67
  opt@mpMinLatF = 7
  opt@mpMaxLonF = 170
  opt@mpMinLonF = 0
  opt@mpGridAndLimbOn = False
  opt@mpGridLineThicknessF = 0.5
  opt@mpGridLonSpacingF = 30
  opt@mpGridLatSpacingF = 15
  ; opt@mpGridLineDashPattern = 1
  ; opt@mpGeophysicalLineColor = "#206e22"
  opt@mpGeophysicalLineColor = "#78CFD5"
  opt@mpGeophysicalLineThicknessF = 2
  opt@mpPerimOn         = False 
  opt@mpCenterLonF = 105
  opt@mpMaxLonF = 180
  opt@mpCenterLatF      = 25.
  opt@mpMinLatF = 0
  opt@gsnLeftString = genItem("A",itemType)
  opt@tiYAxisString = "P1"
  opt@tiYAxisAngleF = 0
  opt@tiYAxisFont = 22
  opt@tiYAxisOffsetXF = -0.01
  opt@tiYAxisFontHeightF = 0.04
  opt@gsnCenterString = "LWA & SH"
  opt@gsnCenterStringFontHeightF = 0.05
  opt@gsnCenterStringOrthogonalPosF = 0.08
plot(4) = plot_base(wks,ranges,opt)
  opt@gsnLeftString = genItem("B",itemType)
  opt@tiYAxisString = ""
  opt@gsnCenterString = "TC & WVT"
plot(5) = plot_base(wks,ranges,opt)

  opt@gsnLeftString = genItem("C",itemType)
  opt@tiYAxisString = "P2"
  opt@gsnCenterString = ""
plot(6) = plot_base(wks,ranges,opt)
  ; opt@mpCenterLonF = 85
  ; opt@mpMaxLonF = 150
  ; opt@mpCenterLatF      = 35.
  ; opt@mpMinLatF = 7
  opt@gsnLeftString = genItem("D",itemType)
  opt@tiYAxisString = ""
  opt@gsnCenterString = ""
plot(7) = plot_base(wks,ranges,opt)

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
  opt@cnLevels = (/-3,-2,-1.5,-1,-0.5,0.5,1,1.5,2,3/)*2
  opt@lbLabelStride = 3
  opt@cnFillDotSizeF = 0.005
  opt@stipplingColor = "white"
  ; opt@cnFillPattern
  opt@mode = "hatching"
  opt@hatchingPattern = 8
  ; opt@hatchingColor = "#dadada"
  opt@hatchingColor = "white"
  opt@hatchingRepeat = 5
  opt@cnFillScaleF = 0.8
  ; opt@cnFillScales = (/0.5,0.5,0.5,0.5,0.5/)
  opt@cnLineThicknessF = 10
  ; opt@cnfill
  ; opt@cnFillOpacityF = 0.1
; add_reg(plot(4),ts0,type,ranges,opt)
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
  opt@hatchingRepeat = 5
  opt@cnFillScaleF = 0.8
  opt@hatchingColor = "White"
; add_cor(plot(0),Jet1,type,ranges,opt)
; add_reg(plot(5),ts0,type,ranges,opt)


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
  ; opt@cnLineColors = (/"#2d8134","#3AA142","#68B75D","#9BCB94","#FEC554","#FEA52C","#F4602A","#C42A1D"/)
  opt@cnLevels := (/-5,-4,-3,-2,2,3,4,5/)
  ; opt@cnMonoLineColor = True
  opt@test = False
  ; opt@lbLabelBarOn = True
; add_reg(plot(5),ESWJ0,type,ranges,opt)
;# 复合事件
type = "CE"
ts_CE := dim_standardize_Wrap(ts0({ispan(1982, 1998, 1)}), 0)
  opt@mode = "stippling"
  opt@cnFillOn = False
  opt@cnLinesOn = False
  opt@cnFillScaleF = 1.2
  opt@cnFillDotSizeF = 0.0045
  opt@test = True
  opt@testSmooth = True
  opt@cnLineThicknessF = 10
; opt@stipplingColor = "#fdcc38"
  opt@stipplingColor = "white"
  opt@lbBoxSeparatorLinesOn = False
  opt@mode = "contour"

; add_reg(plot(4),ts_CE,type,ranges,opt)

; add_reg(plot(5),ts_CE,type,ranges,opt)
;# fig.2f LWA
;LWA只能从1979开始
type := "lwa"
  ; type@source = "ersstv5"
  type@source = "era5"
  type@month = (/7,8/)
  type@range := (/0,90,-80,260/)
  type@level = 200
opt := True
notDrawAndFrame(opt)
  opt@cnFillDotSizeF = 0.0045
  opt@cnFillDotOpacityF = 0.9
  opt@cnFillScaleF = 1.2
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
type@year = ts1&year
method := "anom"
lwa := process(type,method)
lwa_reg := regCoef_n(ts1, lwa, 0, 0)
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
  opt@pmLabelBarOrthogonalPosF = 0.05
add_cn(plot(6),lwa_reg,ranges,opt)



tval := get_tval(lwa_reg)
t := t_value(22)
res_test := True
notDrawAndFrame(res_test)
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
  level = 95
  res_test@cnLevel = t@$("t"+level)$
  res_test@hatchingPattern = 8
  res_test@hatchingColor = "White"
  res_test@cnFillDotSizeF = 0.0045
  res_test@cnFillScaleF = 1.2
  res_test@cnFillDotOpacityF = 0.8
  add_dots(plot(6),tval,ranges,res_test)

type@year := ts0&year
method := "anom"
lwa := process(type,method)
lwa_reg := regCoef_n(ts0, lwa, 0, 0)
copy_VarCoords(lwa(0,:,:), lwa_reg)
tem := lwa_reg({0:45},{0:180})
lwa_reg({0:45},{0:180}) = where(tem > 0, 0, tem)
lwa_reg({0:40},{50:120}) = 0
lwa_reg({0:25},{120:180}) = 0
  opt@lbLabelBarOn = False

add_cn(plot(4),lwa_reg,ranges,opt)
tval := get_tval(lwa_reg)
t := t_value(22)
res_test := True
notDrawAndFrame(res_test)
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
  level = 95
  res_test@cnLevel = t@$("t"+level)$
  res_test@hatchingPattern = 8
  res_test@hatchingColor = "White"
  res_test@cnFillDotSizeF = 0.0045
  res_test@cnFillScaleF = 1.2
  res_test@cnFillDotOpacityF = 0.8
  add_dots(plot(4),tval,ranges,res_test)

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
  opt@lbLabelBarOn = False
  opt@lbOrientation = "Horizontal"
  opt@pmLabelBarOrthogonalPosF = -0.27
  opt@pmLabelBarParallelPosF = 0.36
  opt@pmLabelBarWidthF = 0.4
  opt@pmLabelBarHeightF = 0.1
  opt@lbTitleOffsetF = 0.2
  opt@lbTitleString = "TC Track Density Corr"
  ; opt@lbTitleJust = "CenterCenter"
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleDirection = "Across"
  opt@lbLabelStride = 1
  opt@lbLabelAutoStride = False
  opt@lbLabelStrings := (/"-0.4","","-0.2","","0.3","","0.5"/)
  ; delete(opt@lbLabelStrings)
  ; opt@lbTitleAngleF = 90
  opt@lbTitleFontHeightF = 0.021
  ; opt@lbTitleOffsetF = 0.2
  opt@lbLabelFormat = "%0.1f"
  opt@lbLabelFontHeightF = 0.021
  opt@lbBoxLineThicknessF = 1
  opt@Scale = 1
  opt@detrend = True
  ; opt@cnFillColors := (/"#F6E9BC","#F1CD5C","#F0BF2A","#bd932a","#A57E1E"/)

  ; opt@cnFillColors := (/"transparent","#E6CC5D","#EB9E17","#e75c40"/)
  opt@cnFillColors := (/"#3AA142","#68B75D","#9BCB94","transparent","#F6E9BC","#F1CD5C","#ecb81d","#e99b00"/)
  opt@cnLineColors := (/"#ff748b","transparent","transparent","transparent","transparent","#ff748b","transparent"/)
  opt@cnLineThicknessF = 10
  ; opt@cnFillColors := (/"transparent","#F6E9BC","#F1CD5C","#F0BF2A"/)
  opt@cnLevels := (/-t@r95,-t@r90,-0.2,0.2,t@r90,t@r95,t@r99/)
  opt@cnFillOn = True
  opt@sigLevel = 95
  t = t_value(21)
  print(t)
  ; exit()
  type = "TDEN"
    type@source = "TC"
    type@range = (/5,50,70,160/)

  ; add_cor(plot(6),ESWJ2({ispan(1999, 2021, 1)}),type,range,opt)
  add_cor(plot(5),ts0,type,range,opt)
  f_tcCor = addfile("/data/TC/TC-corr.nc", "r")
  tcCor := f_tcCor->a(0,0,{5:50},{70:150})
  ; tcCor = (/where(tcCor .le. 0 .or. ismissing(tcCor), 0, tcCor)/)
  ; range = (/0,30,80,120/)
  opt@lbLabelBarOn = True
  add_cn(plot(7),tcCor,range,opt)
  ; add_cn(plot(5),tcCor,range,opt)

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
add_cn(plot(4),SAH_clim0,ranges,opt)
    opt@cnLevels = (/WNPSH_level/)
    opt@cnFillColors := (/"transparent","tomato"/)
    opt@cnFillOn = True
    opt@cnLinesOn = False
; add_cn(plot(6),WNPSH_clim1,ranges,opt)
add_cn(plot(6),WNPSH_clim1,ranges,opt)
add_cn(plot(4),WNPSH_clim0,ranges,opt)
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
add_cn(plot(6),WPSH_h1,ranges,reso)
add_cn(plot(4),WPSH_h0,ranges,reso)

    reso@cnLineDashPattern = 16
    reso@cnLineThicknessF           = 10
    reso@cnLineColor = "coral"
; add_cn(plot(6),WPSH_l,ranges,reso)
add_cn(plot(6),WPSH_l1,ranges,reso)
add_cn(plot(4),WPSH_l0,ranges,reso)

    reso@cnLevels := SAH_level
    ; reso@cnLevels := (/14350,14400/)
    reso@cnLineThicknessF = 15
    reso@cnLineDashPattern = 0
    reso@cnLineColor = "dodgerblue3"
; add_cn(plot(6),SAH_h,ranges,reso)
add_cn(plot(6),SAH_h1,ranges,reso)
add_cn(plot(4),SAH_h0,ranges,reso)

    reso@cnLineDashPattern = 16
    reso@cnLineThicknessF = 10
    reso@cnLineColor = "deep sky blue"
; add_cn(plot(6),SAH_l,ranges,reso)
add_cn(plot(6),SAH_l1,ranges,reso)
add_cn(plot(4),SAH_l0,ranges,reso)
;# 加TPH和WNPSH标签
res_text := "TPH"
  res_text@txFont = 22
  res_text@txFontColor = "dodgerblue3"
  res_text@txFontHeightF = 0.04
  res_text@txFontThicknessF = 5
  res_text@txAngleF = -20
; add_text(plot(6),res_text,72,29)
add_text(plot(6),res_text,72,29)
add_text(plot(4),res_text,72,29)
  res_text = "WNPSH"
  res_text@txFontColor = "firebrick2"
  res_text@txFontThicknessF = 5
  res_text@txFontHeightF = 0.04
  res_text@txAngleF = 30
; add_text(plot(6),res_text,165,23)
add_text(plot(6),res_text,155,28)
  res_text@txFontHeightF = 0.035
add_text(plot(4),res_text,155,28)

;# fig.2g 降水
;GPCP只能从1979开始
type = "precip"
  type@source = "GPCP"
  ; type@level = 1000
  type@range = (/0,90,0,360/)
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

; add_reg(plot(7),ts1,type,ranges,opt)
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

; add_reg(plot(7),ts0,type,ranges,opt)
;# 水汽输送
  type_vc := "water_vapor_flux"
    type_vc@level = 850
    type_vc@month = type@month
    type_vc@source = "era5"
    type_vc@range = type@range
    type_vc@range(0) = 0
  rvc := True
    rvc@vcRefMagnitudeF = 30
    rvc@vcRefLengthF = 0.15
    rvc@vcLineArrowHeadMaxSizeF = 0.01
    rvc@vcLineArrowHeadMinSizeF = 0.01
    ; rvc@vcFillArrowMinFracWidthF = 0.1
    rvc@vcMinDistanceF = 0.045
    rvc@vcLineArrowThicknessF = 4
    rvc@test = False
    ; rvc@vcColorsOn = True
    ; rvc@vcLevels = (/5,10,15,20/)
    ; rvc@vcLevelColors = (/"White","Green","Blue","Red","Magenta"/)
    rvc@vcMinMagnitudeF = 0
    ; rvc@vcMaxMagnitudeF = 10
    ; rvc@vcMonoLineArrowColor = False
    rvc@vcRefAnnoParallelPosF = 0.98
    rvc@vcRefAnnoOrthogonalPosF = 0.05
    rvc@vcRefAnnoFontHeightF = 0.02
    rvc@vcRefAnnoPerimOn = False
    rvc@vcLineArrowColor = "DodgerBlue"
    rvc@smoothing = True
    rvc@vcColorsOn = True
    rvc@sigLevel = 95
  add_reg_vc(plot(7),ts1,type_vc,range,rvc)
    rvc@vcRefAnnoOn = False
  add_reg_vc(plot(5),ts0,type_vc,range,rvc)

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 5.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
range(2) = 40
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
  add_line(plot(4),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(5),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(6),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(7),lat_JA_new&lon,lat_JA_new,line)
;# 组图
resp := True
  resp@gsnFrame = False
  ; resp@gsnPanelScalePlotIndex = 1
  resp@gsnPanelYWhiteSpacePercent = 0.
  resp@gsnPanelXWhiteSpacePercent = 5.
  ; resp@gsnPanelRowSpec = True
  ; resp@gsnPanelXF = (/0.7,0.02,0.37,0.7/)
  ; resp@gsnPanelYF = (/0.5,0.22,0.22,0.22/)
  ; resp@gsnPanelScaleF = (/0.3,0.3,0.3,0.3/)
  resp@gsnMaximize = True
  ; resp@gsnPanelLeft = -0.1
  ; resp@gsnPanelDebug = True
  ; resp@gsnPanelGridYF = 0.4
gsn_panel(wks,plot(4:),(/2,2/),resp)


frame(wks)
; delete(wks)
show(fileName+".png")
end