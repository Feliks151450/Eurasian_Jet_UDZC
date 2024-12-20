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
  clr = (/"red","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
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

;函数定义
undef("projection")
function projection(data,pattern)
local ts,dims,patterns
begin
  dims = dimsizes(pattern)
  patterns = new((/1,dims(0),dims(1)/),typeof(data))
  patterns!0 ="env"
  patterns(0,:,:) = pattern
  ts = eofunc_ts_n_Wrap(data, patterns, True,0)
  return ts(0,:)
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
  WNPSH_level = 5870
  SAH_level = 14360
  labelColor = "#434343"
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
  type@range = (/20,65,0,150/)
  ; type@range = (/20,65,20,150/)
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
    EAJ2@units = ""
    pcvar2 := EAJ2@pcvar
EOF_pattern = regCoef_n(EAJ2(0,:), X, 0, 0)

    type@year := year01
X := process(type,opt)
EAJ01 := EOF(X,opt)
    EAJ01@units = ""
    pcvar01 := EAJ01@pcvar
EOF1_p0 := EAJ0(0,:)
EOF1_p1 := EAJ1(0,:)  
EOF1_p2 := EAJ2(0,:)  
EOF1_p01 := EAJ01(0,:)  

EOF2_p0 := EAJ0(1,:)
EOF2_p1 := EAJ1(1,:)  
EOF2_p2 := EAJ2(1,:)  
EOF2_p01 := EAJ01(1,:) 
;# 投影得到指数
    type@year := year
X := process(type,opt)
Xw = latWeight(X)
EWJA = projection(X,EOF_pattern)
EWJA = dim_standardize_Wrap(EWJA, 0)
EWJA01 = dim_standardize_Wrap(EWJA({year01}), 0)
EWJA2 = dim_standardize_Wrap(EWJA({year2}), 0)

ts := EWJA
ts({year01}) = (/designal(ts({year01}),EAJ01(0,:))/)
ts = (/dtrend_leftdim(ts, True)/)

remove("ESWJ_index.nc")
fout = addfile("ESWJ_index.nc", "c")
fout->EWJA = EWJA
fout->EWJA_modified = ts
; print(EWJA)
; print(escorc(EWJA({year2}), EAJ2(0,:)))
print(escorc(ts({year01}), EAJ01(0,:)))
print(escorc(ts({year01}), EAJ01(1,:)))
print(escorc(ts({year2}), EAJ2(0,:)))
print(escorc(ts({year2}), EAJ2(1,:)))
print(escorc(WAJ_index({year01}), EAJ01(0,:)))
print(escorc(WAJ_index({year01}), EAJ01(1,:)))
print(escorc(WAJ_index({year2}), EAJ2(0,:)))
print(escorc(WAJ_index({year2}), EAJ2(1,:)))
print(escorc(EAJ_index({year01}), EAJ01(0,:)))
print(escorc(EAJ_index({year01}), EAJ01(1,:)))
print(escorc(EAJ_index({year2}), EAJ2(0,:)))
print(escorc(EAJ_index({year2}), EAJ2(1,:)))
print(t_value(dimsizes(year01)))
print(t_value(dimsizes(year2)))
tem = EAJ01(0,:)
tem = EAJ01(1,:)
; exit()
;# EOF1
ts0 := EAJ0(0,:)
ts1 := EAJ1(0,:)  
ts2 := EAJ2(0,:)  
ts01 := EAJ01(0,:)  

;卫星投影
modeIndex = 0
ts0 := EAJ01(modeIndex,:)
ts1 := EAJ1(modeIndex,:)  
ts2 := EAJ2(modeIndex,:)  
fileName = "NC_fig2"
itemType = "Nature"
wks = gsn_open_wks(png,fileName)
;# fig1A-D
ranges := (/20,65,0,150/)
size := 4
  ; size@vpHeightF = 0.55
  ; size@vpWidthF = 0.9
  size@vpHeightF = 0.53
  size@vpWidthF = 0.8
  size@tmYLLabelsOn = (/True,False,True,False/)
  size@tmXBLabelsOn = (/False,False,True,True/)
  ; size@gsnLeftString = (/"EOF1 "+min(year0)+"-"+max(year0),min(year1)+"-"+max(year1),min(year2)+"-"+max(year2)/)
  size@gsnLeftString = (/"~F22~U200 EOF1~F21~","~F22~U200 EOF2~F21~","",""/)
  ; size@tiMainString = (/genItem("a",itemType)+"   "+min(year01)+"-"+max(year01),genItem("b",itemType)+"   "+min(year2)+"-"+max(year2),genItem("c",itemType)+"   "+min(year01)+"-"+max(year01),genItem("d",itemType)+"   "+min(year2)+"-"+max(year2)/)
  size@tiMainString = (/genItem("a",itemType),genItem("b",itemType),genItem("c",itemType),genItem("d",itemType)/)
  size@tiMainFontHeightF = 0.05
  size@tiMainFont = 21
  ; size@tiMainOffsetYF = (/-0.015,-0.015,0.02,0.02/)-0.065
  size@tiMainOffsetYF = (/-0.02,-0.02,0.02,0.02/)-0.06
  size@tiMainOffsetXF = -0.13
  size@tiYAxisString = (/"~F22~1958-1998~F21~","","~F22~1999-2022~F21~",""/)
  size@tiYAxisFontHeightF = 0.038
  ; size@tiYAxisOffsetXF = -0.01
  size@gsnLeftStringFontHeightF = 0.045
  size@gsnLeftStringParallelPosF = 0.31
  size@gsnLeftStringOrthogonalPosF = 0.11
  size@tmXBTickSpacingF = 45
  ; size@mpProjection = "LambertConformal"
  size@mpLambertParallel1F = 20
  size@mpLambertParallel2F = 55
  ; size@gsnMaskLambertConformal = True
  size@mpGridAndLimbOn = True
  size@mpGridLonSpacingF = 30
  size@mpGridLatSpacingF = 15
  size@mpGridLineThicknessF = 0.5
  ; size@mpGridLineDashPattern = 1
  size@mpGeophysicalLineColor = "#206e22"
  size@mpPerimOn         = False 
  ; size@mpPerimDrawOrder = "PostDraw"

  size@mpProjection      = "Satellite"
  size@mpCenterLatF      = 35.
  size@mpLandFillColor = "transparent"
  size@mpCenterLonF = 80
  size@mpLimitMode = "LatLon"
  size@mpMaxLatF = 67
  size@mpMinLatF = 7
  size@mpMaxLonF = 175
  size@mpMinLonF = 0
; fileName = folder+"change_in_mode"
; wks = gsn_open_wks(png,fileName)
plot := plot_bases(wks,ranges,size)
type := "u"
  type@level = 200
  type@month = (/7,8/)
  type@source = "ERA5"
  type@range = ranges
  type@range(0) = 10
  type@range(1) = 69
  type@range(2) = 0
  type@range(3) = 360
opt := True
optreg := True
notDrawAndFrame(opt)
  opt@Scale = 0.7
  opt@gsnStringBold = True
  opt@lbLabelBarOn = False
  opt@pmLabelBarWidthF = 0.7
  opt@lbLabelStride = 3

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
  opt@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  t = t_value(dimsizes(year01))
  print(t)
  ; opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.55,-0.5,-0.45,-t@r90,t@r90,0.45,0.5,0.55,0.6,0.7,0.8,0.9/)
  opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.5,-0.4,-0.3,-0.25,0.25,0.3,0.4,0.5,0.6,0.7,0.8,0.9/)
add_cor(plot(0),EOF1_p01,type,ranges,opt)
add_cor(plot(1),EOF2_p01,type,ranges,opt)
  ; opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.55,-0.5,-0.45,-0.3783408,0.3783408,0.45,0.5,0.55,0.6,0.7,0.8,0.9/)
; add_cor(plot(1),ts1,type,ranges,opt)
  t = t_value(dimsizes(year2))
  print(t)
  ; opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.55,-0.5,-0.45,-t@r90,t@r90,0.45,0.5,0.55,0.6,0.7,0.8,0.9/)
add_cor(plot(2),EOF1_p2,type,ranges,opt)
add_cor(plot(3),EOF2_p2,type,ranges,opt)
optreg@cnFillOn = False
optreg@cnLinesOn = True
optreg@test = True
optreg@mode = "hatching"
optreg@hatchingRepeat = 1
optreg@hatchingColor = "#cecece"
optreg@cnFillScaleF = 1
; optreg@hatchingPattern = 8
optreg@sigLevel = 95
optreg@cnLineThicknessF = 2.
optreg@Scale = 1.
optreg@smoothing = True
; optreg@cnLineLabelsOn = True
; optreg@cnLineLabelInterval = 1
; ; optreg@cnLineLabelBackgroundColor = "transparent"
; optreg@cnLineLabelFontColor = "#206e22"
; optreg@cnLineLabelFont = 22
; optreg@cnLineLabelFontHeightF = 0.02
add_reg(plot(0),EOF1_p01,type,ranges,optreg)
add_reg(plot(1),EOF2_p01,type,ranges,optreg)
; add_reg(plot(1),ts1,type,ranges,optreg)
add_reg(plot(2),EOF1_p2,type,ranges,optreg)
add_reg(plot(3),EOF2_p2,type,ranges,optreg)

  opt@cnLevels := 20
  opt@cnLineThicknessF = 10
  opt@cnLineColor := "#eece00"
  opt@Scale = 1
type@year = year  
; add_clim(plot(0),type,ranges,opt)
; add_clim(plot(1),type,ranges,opt)
; add_clim(plot(2),type,ranges,opt)
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
    line@gsLineThicknessF = 15
    line@gsLineDashPattern = 0
    ; line@gsLineColor = "#c872fe"
    line@gsLineColor = "#eece00"
    line@txJust = "BottomLeft"
    line@txFontColor = "#0000ff"
  lat_JA_new = lat_JA({23:123})
  add_line(plot(0),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(1),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(2),lat_JA_new&lon,lat_JA_new,line)
  add_line(plot(3),lat_JA_new&lon,lat_JA_new,line)

box := (/20,65,00,150/)
  box@gsLineThicknessF = 3
  box@gsLineColor = "Magenta"
  box@gsLineDashPattern = 1
add_lineBox(plot(0),box)
add_lineBox(plot(1),box)
add_lineBox(plot(2),box)
add_lineBox(plot(3),box)

rlable := True
  rlable@lat_spacing = 25
  rlable@tmYLLabelsOn = True
  rlable@tmYLOn = True
  rlable@lon_spacing = 30
  rlable@txFontHeightF = 0.025
  ; ranges(0) = 15
  ; rlable@txAngleF = 0
  ; print(ranges)
; add_lc_labels(plot(0),ranges,rlable)
; add_lc_labels(plot(1),ranges,rlable)
; add_lc_labels(plot(2),ranges,rlable)
; add_lc_labels(plot(3),ranges,rlable)

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 5.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
ranges(2) = 40
add_topo(plot(0),ranges,3000,res_topo)
add_topo(plot(1),ranges,3000,res_topo)
add_topo(plot(2),ranges,3000,res_topo)
add_topo(plot(3),ranges,3000,res_topo)

;# 前四张组图
resp := True
  ; resp@gsnPanelMainString = "U200 EOF1"
  resp@gsnPanelLabelBar = True
  resp@lbLabelFontHeightF = 0.015
  resp@lbLabelStride = 3
  resp@lbTitleString = "Correlation"
  resp@lbTitleFontHeightF = 0.015
  resp@lbTitlePosition = "Right"
  resp@lbTitleDirection = "Across"
  resp@lbBoxSeparatorLinesOn = False
  resp@lbBoxLineThicknessF = 3
  resp@pmLabelBarHeightF = 0.05
  resp@pmLabelBarWidthF = 0.7
  resp@pmLabelBarOrthogonalPosF = 0
  resp@pmLabelBarParallelPosF = -0.07
  resp@gsnFrame = False
  ; resp@gsnPanelBottom = 0.5
  ; resp@gsnPanelXF = (/0.04,0.4,0.04,0.4/)
  resp@gsnPanelXF = (/0.04,0.39,0.04,0.39/)
  resp@gsnPanelYF = (/0.418,0.418,0.17,0.17/)+0.53
  resp@gsnPanelScaleF = (/0.38,0.38,0.38,0.38/)
  resp@gsnPanelXWhiteSpacePercent = 5
gsn_panel(wks,plot,(/2,2/),resp)

;# 时间序列
opt := True
notDrawAndFrame(opt)
  opt@gsnLeftString = genItem("e",itemType)+"  ESWJ Index"
  opt@gsnLeftStringFontHeightF = 0.025
  opt@gsnLeftStringOrthogonalPosF = 0.045
  opt@gsnLeftStringParallelPosF = -0.03
  opt@gsnRightString = "&         Index"
  opt@gsnRightStringOrthogonalPosF = 0.05
  opt@gsnRightStringFontHeightF = 0.022
  opt@gsnCornerStringFontHeightF = 0.035
  opt@gsnCornerOffsetXF = 0.05
  opt@tiXAxisString = "Year"
  opt@tiXAxisFontHeightF = 0.02
  opt@tiYAxisString = "std. dev."
  opt@tiYAxisFontHeightF = 0.02
  opt@tiYAxisOffsetXF = 0.005
  opt@tmXBTickSpacingF = 10
  opt@tmXBTickStartF = 1960
  opt@vpHeightF = 0.38
  opt@vpWidthF = 1.27
  opt@tmXBLabelFontHeightF = 0.02
  opt@tmXBLabelFontColor = labelColor
  opt@tmYLLabelFontHeightF = 0.02
  opt@tmYLLabelFontColor = labelColor
  ; opt@tmYLLabelDeltaF = -0.8
  opt@tmYLValues = (/-4,-2,0,2,4/)
  ; opt@tmYLFormat = "%0.0f"
  ; opt@trYMaxF = 7
  ; opt@trYMinF = -7
  opt@minmax = (/-3.35,3.4/)
  ; opt@tmYLLabelFont = 22
  opt@tmYROn = False
  opt@tmYUseLeft = False
  opt@tmYRMinorOn = False
  opt@tmYRValues = (/-7.5,-5,-2.5,0,2.5,5,7.5/)
  opt@tmYRLabelsOn = True
  opt@tmYRLabelFontHeightF = 0.015
  opt@tmYRMode = "Explicit"
  opt@tmYRLabelDeltaF = -0.5
  opt@tmYRMajorThicknessF = 5
  opt@gsnXYBarChartBarWidth = 0.5
  ; opt@tmYRTickStartF = -4
  ; opt@tmYRTickEndF = 4
  opt@tmYRLabels = (/"-3","-2","-1","0","1","2","3"/)
  ; opt@gsnXYBarChartColors = "#F1CD5C"
  opt@gsnXYBarChartColors = "Black"
  opt@gsnXYBarChartFillOpacityF = 0.8

  ; opt@tmYRLabelFontHeightF = 0.01
  ; opt@tmYRLabelFontColor = "tomato"
; plot(0) = gsn_csm_xy(wks, Jet_ERA5&year, Jet_ERA5, opt)
; print(combined_index)
; combined_index = (/dtrend_leftdim(combined_index, True)/)
ts := EWJA
ts({year01}) = (/designal(ts({year01}),EAJ01(0,:))/)
ts = (/dtrend_leftdim(ts, True)/)
print(escorc(ts({year01}), EAJ01(0,:)))



; exit()
; ts := combined_index
plotEAWJ = plot_ts(wks,ts,opt)
; resTrend := True
;   resTrend@xyDashPattern = 1
;   resTrend@xyLineThicknesses = 7
; add_ts(plotEAWJ,run_trend_ERA5,resTrend)
;   resTrend@xyDashPattern = 0
;   resTrend@xyLineThicknesses = 20
; add_ts(plotEAWJ,run_trend_sig,resTrend)
; singleBar = combined_index(dimsizes(combined_index)-1);7.066552
;   singleBar@gsnAboveYRefLineColor = "Red"
;   singleBar@gsnXYBarChartBarWidth = 0.6
; add_singleBar(plotEAWJ,2022,singleBar)
;# fig1b 背景
pgres := (/-10,10,min(year2)-0.5,2023/)
  pgres@gsFillOpacityF = 0.05
  pgres@gsFillColor = "#ff8747"
add_fillBox(plotEAWJ,pgres)
yref := (/-stddev(ESWJ),stddev(ESWJ)/)
  yref@polyYRefDashPattern = 1
  yref@polyYRefColor = "DodgerBlue"
; add_Yref(plotEAWJ,yref)
; print(cor)


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
; opt@xyMarkLineMode = "Markers"
; print(t_value(18))
  opt@xyLineThicknessF = 15
; nblc = newBoldHolyCircle(wks)
; opt@xyMarkers = nblc
; opt@xyMarkerSizeF = 0.015
WAJ_index2 = dim_standardize_Wrap(WAJ_index({year2}), 0)
add_ts(plotEAWJ,WAJ_index2,opt)
opt@xyLineColor = "firebrick1"
ts1_amp := ts1*2.5
copy_VarCoords(ts1, ts1_amp)
EAJ_index2 = dim_standardize_Wrap(EAJ_index({year2}), 0)
add_ts(plotEAWJ,EAJ_index2,opt)
opt@xyLineColor = "DimGray"
opt@xyLineThicknessF = 5
opt@xyMarkLineMode = "Lines"
add_ts(plotEAWJ,EOF1_p01,opt)
add_ts(plotEAWJ,EOF1_p2,opt)
opt@xyLineColor = "DimGray"
opt@xyDashPattern = 13
add_ts(plotEAWJ,EOF2_p01,opt)
add_ts(plotEAWJ,EOF2_p2,opt)

opt@xyMarkLineMode = "MarkLines"
opt@xyMarker = 4
opt@xyMarkerSizeF = 0.014
; opt@xyMarkerThicknessF
; add_ts(plotEAWJ,ts2,opt)
ts_tem := dim_standardize_Wrap(ESWJ({year01}), 0)
text := "R (ESWJ, WJA) = "+sprintf("%0.2f", escorc(EWJA2,WAJ_index2))+", p < 1e-5"
; text := "R = "+sprintf("%0.2f", escorc(ts0, ESWJ0))+", p<0.01"
  text@txFontHeightF = 0.02
  text@txFontColor = "DodgerBlue"
  text@txFont = 22
add_text(plotEAWJ,text,2011,-2.9)
; add_text(plotEAWJ,text,1965,-6.)

text = "R (ESWJ, EJA) = "+sprintf("%0.2f", escorc(EWJA2,EAJ_index2))+", p < 1e-5"
; text = "R = "+sprintf("%0.2f", escorc(ts2, ESWJ2))+", p<0.01"
  text@txFontColor = "firebrick1"
add_text(plotEAWJ,text,2011,2.9)

text = "PC1"
  text@txFontColor = "DimGray"
  text@txJust = "CenterLeft"
add_text(plotEAWJ,text,1962,-2.5)
text = "PC2"
add_text(plotEAWJ,text,1970,-2.5)

resLine := True
  resLine@gsLineThicknessF = 5
  resLine@gsLineColor = "DimGray"
add_line(plotEAWJ,(/1958,1961/),(/-2.5,-2.5/),resLine)
  resLine@gsLineDashPattern = 13
add_line(plotEAWJ,(/1966,1969/),(/-2.5,-2.5/),resLine)
text := "WJA"
  text@txFontColor = "#0082df"
  text@txJust = "CenterLeft"
  text@txFontHeightF = 0.022
textY = 1.225
add_string(plotEAWJ,text,0.81,textY)

text = "EJA"
  text@txFontColor = "red"
add_string(plotEAWJ,text,0.891,textY)

resp := True
  resp@gsnFrame = False
  resp@gsnPanelXF = 0.08
  resp@gsnPanelYF = 0.35
  resp@gsnPanelBottom = 0.05
  resp@gsnPanelTop = 0.292
  resp@gsnMaximize = True
  resp@gsnPanelScaleF = 0.7
gsn_panel(wks,plotEAWJ,(/1,1/),resp)



;# 热力图
data := (/\
  (/0.025,0.135/),\
  (/-0.533,0.171/),\
  (/-0.288,-0.18/),\
  (/0.999,0.005/),\
  (/0.855,0.269/),\
  (/0.957,0.002/)\
/)
dataColor := (/\
  (/"Grey30","Grey30"/),\
  (/"White","Grey30"/),\
  (/"Grey30","Grey30"/),\
  (/"White","Grey30"/),\
  (/"White","Grey30"/),\
  (/"White","Grey30"/)/)
dataFont := (/\
  (/21,21/),\
  (/21,21/),\
  (/21,21/),\
  (/22,21/),\
  (/22,21/),\
  (/22,21/)/)
data = data(::-1,:)
dataColor = dataColor(::-1,:)
dataFont = dataFont(::-1,:)
;---Set levels and colors to use
  levels := (/-0.9,-0.8,-0.7,-0.6,-0.5,-0.4,-0.3,-0.25,0.25,0.3,0.4,0.5,0.6,0.7,0.8,0.9/)
  colors = (/"ForestGreen","ForestGreen","ForestGreen","ForestGreen","ForestGreen","Grey97","Grey97","Grey97","Grey97","Grey97","Grey97","Grey97","Grey97","Grey97","Grey97","red","red"/)
opt := True
notDrawAndFrame(opt)
  opt@tmXBTickSpacingF = 10
  opt@vpHeightF = 0.45
  opt@vpWidthF = 0.18
  opt@vpXF = 0.79
  opt@vpYF = 0.95
  opt@pmLabelBarWidthF = 0.9
  opt@pmLabelBarHeightF = 0.07
  ; opt@tmXBLabels = (/"1950","1960","1970","1980","1990","2000","2010","2020"/)
  opt@pmLabelBarOrthogonalPosF = 0.65
  opt@gsnLeftString = "~F22~f~F21~"
  opt@gsnLeftStringFontHeightF = 0.02
  opt@gsnLeftStringParallelPosF = -0.02
  opt@gsnLeftStringOrthogonalPosF = -0.04
  opt@gsnLeftStringFontColor = "Black"
  opt@lbLabelFontHeightF = 0.013
  opt@lbTitleString = "Correlation"
  opt@lbTitlePosition = "Right"
  opt@lbTitleDirection = "Across"
  opt@lbTitleFontHeightF = 0.013
  opt@gsnPaperOrientation = "portrait"
  opt@tmGridDrawOrder = "PostDraw"
  opt@tmYLLabelFontHeightF = 0.01
  opt@tmXBLabelFontHeightF = 0.012
  opt@tmYLLabelJust = "CenterCenter"
  opt@tmYLMajorLengthF = 0.003
  opt@tmYLMajorOutwardLengthF = 0.003
  opt@tmYLOn = True
  opt@tmYLMode = "Explicit"
  opt@tmYLValues = (/1,2,3,4,5,6/)-0.5
  opt@tmYLLabels = (/"EJA","WJA","ESWJ","EJA","WJA","ESWJ"/)
  opt@tmYLLabelFontHeightF = 0.013
  opt@tmYLLabelJust = "CenterCenter"
  opt@tmXMinorGrid = False
  opt@tmYMinorGrid = False
  opt@tmXBLabelsOn = False
  opt@tmXBOn = False
  opt@tmXUseBottom = False
  opt@tmXTValues = (/0.5,1.5/)
  opt@tmXTLabelFontHeightF = 0.015
  opt@tmXTMode = "Explicit"
  opt@tmXTLabels = (/"PC1","PC2"/)
  opt@tmXTLabelsOn = True
  opt@tmXTLabelFontHeightF = 0.013
  opt@tmXTLabelDeltaF = -0.3
  opt@tmXTOn = True
  opt@tiYAxisString = "~F22~1958-1998                           1999-2022~F21~"
  opt@tiYAxisFontHeightF = 0.014
  opt@tiYAxisOffsetXF = 0.022
  opt@tiYAxisAngleF = -90
  opt@tiYAxisOffsetXF = 0.279
  opt@gsnMaximize = False
  opt@lbLabelBarOn = False
  opt@txFontHeightF = 0.015
  ; opt@txFontColor = "DimGrey"
  opt@hmLabelFormat = "%0.3f"
  opt@hmTxFontColor = dataColor
  opt@hmTxFont  = dataFont
  ; opt@tfPolyDrawOrder = "PostDraw"
  ; opt@wkOrientation = "landscape"
  ; opt@gsnMaximize = False
  ; opt@pmLabelBarHeightF = 0.1
plot := heatmap(wks,data,levels,colors,opt)
draw(plot)
res_line := True
  res_line@gsLineThicknessF = 10
  res_line@gsLineDashPattern = 16
  res_line@tfPolyDrawOrder = "PostDraw"
  res_line@gsFillColor = "#FFBE00"
gsn_polygon_ndc(wks, (/0.5,0.5,0.508,0.508/)+0.47, (/0.725,0.9505,0.9505,0.725/), res_line)
  res_line@gsFillColor = "#4D4D4D"
gsn_polygon_ndc(wks, (/0.5,0.5,0.508,0.508/)+0.47, (/0.7255,0.951,0.951,0.7255/)-0.226, res_line)

; gsn_polyline_ndc(wks, (/0.5,0.5/), (/0.7,0.9/), resLine)
; pgres := (/-10,10,1998.5,2023/)
;   pgres@gsFillOpacityF = 0.1
;   pgres@gsFillColor = "#58BFD8"
; add_fillBox(plot_ESWJ,pgres)
; draw(plot_ESWJ)
; frame(wks)
; delete(wks)
; ; system("gs -q -sDEVICE=png16m -sBATCH -sOutputFile="+fileName+".png -dNOPAUSE -r200 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "+fileName+".pdf")
; show(fileName)
frame(wks)
show(fileName+".png")
end