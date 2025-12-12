begin ;记录全局参数
  ; start_time = get_cpu_time()
  pwd = systemfunc("pwd")
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
  if( .not. fileexists(path))then
    print("data file does not exist: "+path)
    exit()
  end if
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

undef("R2t")
function R2t(R,df)
begin
  return sqrt(df)*abs(R)/sqrt(1-R^2)
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

  test = test0
  folder = test@folder ;"EAJ_plot"
  window = test@window
  rangeWAJ = test@rangeWAJ
  rangeEAJ = test@rangeEAJ
window = 21
rangeWAJ := (/20, 70, 40, 80./)
rangeEAJ := (/20, 70, 90, 123./)
  setBufferPath(localpath(3)+".buffer/")
  bufferMode = "disabled"
  ; bufferMode = "smart"
  pdf = "pdf"
    pdf@wkPaperWidthF = 60
    pdf@wkPaperHeightF = 60
  png = "png"
    png@wkHeight = 2000
    png@wkWidth = 2000
  year := ispan(1958, 2022, 1)
  year0 := ispan(1958, 1978, 1)
  year1 := ispan(1979, 1998, 1)
  year2 := ispan(1999, 2022, 1)
  month = (/7,8/)
  setDim(year,0,"year",year)
  setDim(year0,0,"year",year0)
  setDim(year1,0,"year",year1)
;# 各套数据的急流轴强度指数及滑动相关
window = 21
type := "u"
  type@source = "era5"
  type@month := (/7,8/)
  type@year := ispan(1940, 2022, 1)
  type@level = 200
  type@range := rangeEAJ
method := "mean"
; cor_ERA5 = readCor("cor_ERA5.nc")
; cor_ncep2 = readCor("cor_ncep2.nc")
; cor_ncep1 = readCor("cor_ncep1.nc")
; cor_erai = readCor("cor_erai.nc")
; cor_jra55 = readCor("cor_jra55.nc")
; cor_cfs = readCor("cor_cfs.nc")
; cor_20th = readCor("cor_20th.nc")
; cor_era20c = readCor("cor_era20c.nc")
; cor_era20cm = readCor("cor_era20cm.nc")
; cor_cera20c = readCor("cor_cera20c.nc")
; cor_cera20c_mean = dim_avg_n_Wrap(cor_cera20c, 0)

; year_all = ispan(1900, 2022, 1)
; cor_all = new((/9,dimsizes(year_all)/), float, cor_ERA5@_FillValue)
; setDim(cor_all,1,"year",year_all)

; cor_all(0,{min(cor_ERA5&year):max(cor_ERA5&year)}) = cor_ERA5
; cor_all(0,{min(cor_jra55&year):max(cor_jra55&year)}) = cor_jra55
; cor_all(0,{min(cor_ncep1&year):max(cor_ncep1&year)}) = cor_ncep1
; cor_all(0,{min(cor_ncep2&year):max(cor_ncep2&year)}) = cor_ncep2
; cor_all(0,{min(cor_cfs&year):max(cor_cfs&year)}) = cor_cfs
; cor_all(0,{min(cor_erai&year):max(cor_erai&year)}) = cor_erai
; cor_all(0,{min(cor_cera20c_mean&year):max(cor_cera20c_mean&year)}) = cor_cera20c_mean
; cor_all(0,{min(cor_era20c&year):max(cor_era20c&year)}) = cor_era20c
; cor_all(0,{1900:max(cor_20th&year)}) = cor_20th({1900:})
; cor_all_mean = dim_avg_n_Wrap(cor_all, 0)
; printVarSummary(cor_all_mean)

  cor_ERA5 = readCor(folder+"cor_ERA5.nc")
  year_all = ispan(1806, 2022, 1)
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
  nYear_all = dimsizes(year_all)
  cor_all = new((/9,nYear_all/), float)
  setDim(cor_all,1,"year",year_all)
  cor_all(0,{cor_ERA5&year}) = cor_ERA5
  cor_all(1,{cor_ncep2&year}) = cor_ncep2
  cor_all(2,{cor_ncep1&year}) = cor_ncep1
  cor_all(3,{cor_erai&year}) = cor_erai
  cor_all(4,{cor_jra55&year}) = cor_jra55
  cor_all(5,{cor_cfs&year}) = cor_cfs
  cor_all(6,{cor_20thCRv3_mean&year}) = cor_20thCRv3_mean
  cor_all(7,{cor_era20c&year}) = cor_era20c
  cor_all(8,{cor_cera20c_mean&year}) = cor_cera20c_mean
  part_cor_all = cor_all(:,{ispan(1870,2015,1)})
  cor_all_mean = dim_avg_n_Wrap(part_cor_all, 0)
  cor_all_mean_trend = run_trend(cor_all_mean, window)
  cor_all_mean_std = cor_all_mean
  dimsize = dimsizes(cor_all_mean_std)
  ; do i = 0, dimsize(0)-1
  ;   elements = part_cor_all(:,i)
  ;   validElementsInd := ind( .not. ismissing(elements))
  ;   if(all(ismissing(validElementsInd)))then
  ;     cor_all_mean_std(i) = 0.
  ;   else
  ;     validElements := elements(validElementsInd)
  ;     tem0 := bootstrap_stat(validElements, 0, 10000, 0, False)
  ;     sd0 := tem0[2]
  ;     ; print(validElements)
  ;     cor_all_mean_std(i) = sd0
  ;   end if
  ; end do
  ; cor_all_mean_std = (/cor_all_mean_std*100/)
  ; print(cor_all_mean_std)
  ; exit()
;Fig.2
folder = ""
plot := newPlots(6)
;# fileName
fileName = folder+"NC_fig7"
fig2png = "png"
  fig2png@wkHeight = 4096
  fig2png@wkWidth = 4096
wks := gsn_open_wks(pdf,fileName)
labelColor = "#434343"
cmipColor = "#368237"
lens2Color = "#9d4aae"
bgColor = "#ff8747"
;# modelsNames
models := (/"ACCESS-CM2","ACCESS-ESM1-5","AWI-CM-1-1-MR","BCC-CSM2-MR","CanESM5","CAMS-CSM1-0","CAS-ESM2-0","CESM2","CESM2-FV2","CESM2-WACCM","CIESM","CMCC-CM2-SR5","CMCC-ESM2","CNRM-CM6-1","CNRM-ESM2-1","E3SM-1-0","E3SM-1-1","E3SM-1-1-ECA","EC-Earth3","EC-Earth3-CC","EC-Earth3-Veg","EC-Earth3-Veg-LR","FGOALS-f3-L","FGOALS-g3","FIO-ESM-2-0","GFDL-CM4","GFDL-ESM4","GISS-E2-1-G","GISS-E2-1-H","GISS-E2-2-G","HadGEM3-GC31-LL","HadGEM3-GC31-MM","IITM-ESM","INM-CM4-8","INM-CM5-0","IPSL-CM6A-LR","KACE-1-0-G","KIOST-ESM","MCM-UA-1-0","MIROC6","MIROC-ES2H","MIROC-ES2L","MPI-ESM1-2-HR","MPI-ESM1-2-LR","MRI-ESM2-0","NESM3","NorESM2-LM","NorESM2-MM","TaiESM1","UKESM1-0-LL"/)

;指数指数滑动相关(读取缓存nc)
f := addfile(folder+"CMIP6_index.nc", "r")
EAJ_index_cmip6 := f->EAJ
WAJ_index_cmip6 := f->WAJ
year_tem := ispan(1900, 2099, 1)
slide_cor_cmip6 := new((/dimsizes(models),dimsizes(year_tem)/),float)
do i = 0, dimsizes(models)-1
  slide_cor_cmip6(i,:) = run_cor(WAJ_index_cmip6(i,:), EAJ_index_cmip6(i,:), 21)
end do
; slide_cor_cmip6(dimsizes(models),:) = dim_avg_n(slide_cor_cmip6(:dimsizes(models)-1,:), 0)
setDim(slide_cor_cmip6,1,"year",year_tem)
slide_cor_cmip6 := slide_cor_cmip6(:,{1910:2089})
slide_cor_cmip6_mean = dim_avg_n_Wrap(slide_cor_cmip6, 0)
print(slide_cor_cmip6_mean)

cor_first_cmip6 := new(dimsizes(models),float)
cor_second_cmip6 := new(dimsizes(models),float)
do i = 0, dimsizes(models)-1
  cor_first_cmip6(i) = escorc(WAJ_index_cmip6(i,{ispan(1920, 1990, 1)}), EAJ_index_cmip6(i,{ispan(1920, 1990, 1)}))
  cor_second_cmip6(i) = escorc(WAJ_index_cmip6(i,{ispan(2000, 2070, 1)}), EAJ_index_cmip6(i,{ispan(2000, 2070, 1)}))
end do
; print(escorc(cor_first_cmip6, cor_second_cmip6))

;# model selection
t = t_value(71)
print(t)
ind_high1_cmip6 := ind(cor_first_cmip6 .ge. t@r95)
ind_high2_cmip6 := ind(cor_second_cmip6 .ge. t@r95)
slide_cor_cmip6_high1 := slide_cor_cmip6(ind_high1_cmip6,:)
slide_cor_cmip6_high2 := slide_cor_cmip6(ind_high2_cmip6,:)
slide_cor_cmip6_high1_mean = dim_avg_n_Wrap(slide_cor_cmip6_high1, 0)
slide_cor_cmip6_high2_mean = dim_avg_n_Wrap(slide_cor_cmip6_high2, 0)
; print(slide_cor_cmip6_high_mean)
; 挑低相关的模式
print(t)
print(cor_first_cmip6)
ind_low1_cmip6 := ind(cor_first_cmip6 .le. t@r95)
ind_low2_cmip6 := ind(cor_second_cmip6 .le. t@r95)
; print(ind_low1_cmip6)
slide_cor_cmip6_low1 := slide_cor_cmip6(ind_low1_cmip6,:)
slide_cor_cmip6_low2 := slide_cor_cmip6(ind_low2_cmip6,:)
slide_cor_cmip6_low1_mean = dim_avg_n_Wrap(slide_cor_cmip6_low1, 0)
slide_cor_cmip6_low2_mean = dim_avg_n_Wrap(slide_cor_cmip6_low2, 0)
; print(slide_cor_cmip6_high_mean)
; 挑两时段都不显著的模式
ind_noChange_cmip6 := ind(cor_first_cmip6 .le. t@r95 .and. cor_second_cmip6 .le. t@r95)
slide_cor_cmip6_noChange := slide_cor_cmip6(ind_noChange_cmip6,:)
slide_cor_cmip6_noChange_mean = dim_avg_n_Wrap(slide_cor_cmip6_noChange, 0)
; 挑相关增加的模式
ind_enhanced_cmip6 := ind(cor_first_cmip6 .lt. cor_second_cmip6)
slide_cor_cmip6_enhanced := slide_cor_cmip6(ind_enhanced_cmip6,:)
slide_cor_cmip6_enhanced_mean = dim_avg_n_Wrap(slide_cor_cmip6_enhanced, 0)
; 挑相关增加且显著的模式
ind_enhanced_high_cmip6 := ind(cor_first_cmip6 .le. cor_second_cmip6 .and. cor_second_cmip6 .ge. t@r95)
slide_cor_cmip6_enhanced_high := slide_cor_cmip6(ind_enhanced_high_cmip6,:)
slide_cor_cmip6_enhanced_high_mean = dim_avg_n_Wrap(slide_cor_cmip6_enhanced_high, 0)
; 挑相关降低的模式
ind_weakend_cmip6 := ind(cor_first_cmip6 .gt. cor_second_cmip6)
slide_cor_cmip6_weakend := slide_cor_cmip6(ind_weakend_cmip6,:)
slide_cor_cmip6_weakend_mean = dim_avg_n_Wrap(slide_cor_cmip6_weakend, 0)

;# lens2
member := (/"1001.001","1021.002","1041.003","1061.004","1081.005","1101.006","1121.007","1141.008","1161.009","1181.010","1231.001","1231.002","1231.003","1231.004","1231.005","1231.006","1231.007","1231.008","1231.009","1231.010","1251.001","1251.002","1251.003","1251.004","1251.005","1251.006","1251.007","1251.008","1251.009","1251.010","1281.001","1281.002","1281.003","1281.004","1281.005","1281.006","1281.007","1281.008","1281.009","1281.010","1301.001","1301.002","1301.003","1301.004","1301.005","1301.006","1301.007","1301.008","1301.009","1301.010"/)
f = addfile(folder+"LENS2_index.nc", "r")
EAJ_index_len2 := f->EAJ
WAJ_index_len2 := f->WAJ
year_tem := ispan(1900, 2099, 1)
slide_cor_lens2 := new((/dimsizes(member),dimsizes(year_tem)/),float)
do i = 0, dimsizes(member)-1
  slide_cor_lens2(i,:) = run_cor(WAJ_index_len2(i,:), EAJ_index_len2(i,:), 21)
end do
; slide_cor(dimsizes(models),:) = dim_avg_n(slide_cor(:dimsizes(models)-1,:), 0)
setDim(slide_cor_lens2,1,"year",year_tem)
slide_cor_lens2 := slide_cor_lens2(:,{1910:2089})
slide_cor_lens2_mean = dim_avg_n_Wrap(slide_cor_lens2, 0)
print(slide_cor_lens2_mean)
printVarSummary(slide_cor_lens2)

cor_first_lens2 := new(dimsizes(models),float)
cor_second_lens2 := new(dimsizes(models),float)
do i = 0, dimsizes(models)-1
  cor_first_lens2(i) = escorc(WAJ_index_len2(i,{ispan(1920, 1990, 1)}), EAJ_index_len2(i,{ispan(1920, 1990, 1)}))
  cor_second_lens2(i) = escorc(WAJ_index_len2(i,{ispan(2000, 2070, 1)}), EAJ_index_len2(i,{ispan(2000, 2070, 1)}))
end do
; print(escorc(cor_first_lens2, cor_second_lens2))
;# model selection
; 挑高相关的模式
t = t_value(71)
print(t)
ind_high1_lens2 := ind(cor_first_lens2 .ge. t@r95)
ind_high2_lens2 := ind(cor_second_lens2 .ge. t@r95)
slide_cor_lens2_high1 := slide_cor_lens2(ind_high1_lens2,:)
slide_cor_lens2_high2 := slide_cor_lens2(ind_high2_lens2,:)
slide_cor_lens2_high1_mean = dim_avg_n_Wrap(slide_cor_lens2_high1, 0)
slide_cor_lens2_high2_mean = dim_avg_n_Wrap(slide_cor_lens2_high2, 0)
; 挑低相关的模式
print(t)
ind_low1_lens2 := ind(cor_first_lens2 .le. t@r95)
ind_low2_lens2 := ind(cor_second_lens2 .le. t@r95)
slide_cor_lens2_low1 := slide_cor_lens2(ind_low1_lens2,:)
slide_cor_lens2_low2 := slide_cor_lens2(ind_low2_lens2,:)
slide_cor_lens2_low1_mean := dim_avg_n_Wrap(slide_cor_lens2_low1, 0)
slide_cor_lens2_low2_mean := dim_avg_n_Wrap(slide_cor_lens2_low2, 0)
; 挑两时段都不显著的模式
ind_noChange_lens2 := ind(cor_first_lens2 .le. t@r95 .and. cor_second_lens2 .le. t@r95)
slide_cor_lens2_noChange := slide_cor_lens2(ind_noChange_lens2,:)
slide_cor_lens2_noChange_mean = dim_avg_n_Wrap(slide_cor_lens2_noChange, 0)
; 挑相关增加的模式
ind_enhanced_lens2 := ind(cor_first_lens2 .lt. cor_second_lens2)
slide_cor_lens2_enhanced := slide_cor_lens2(ind_enhanced_lens2,:)
slide_cor_lens2_enhanced_mean = dim_avg_n_Wrap(slide_cor_lens2_enhanced, 0)
; 挑相关增加且显著的模式
ind_enhanced_high_lens2 := ind(cor_first_lens2 .le. cor_second_lens2 .and. cor_second_lens2 .ge. t@r95)
slide_cor_lens2_enhanced_high := slide_cor_lens2(ind_enhanced_high_lens2,:)
slide_cor_lens2_enhanced_high_mean = dim_avg_n_Wrap(slide_cor_lens2_enhanced_high, 0)
; 挑相关降低的模式
ind_weakend_lens2 := ind(cor_first_lens2 .gt. cor_second_lens2)
slide_cor_lens2_weakend := slide_cor_lens2(ind_weakend_lens2,:)
slide_cor_lens2_weakend_mean = dim_avg_n_Wrap(slide_cor_lens2_weakend, 0)

;计算CMIP6和LENS2下挑选的模式的模式平均和误差棒
cor_first_plot := cor_first_cmip6(ind_enhanced_high_cmip6)
cor_second_plot := cor_second_cmip6(ind_enhanced_high_cmip6)
tem0 := bootstrap_stat(cor_first_plot, 0, 10000, 0, False)
tem1 := bootstrap_stat(cor_second_plot, 0, 10000, 0, False)
cmip6_mean0 = avg(cor_first_plot)
cmip6_mean1 = avg(cor_second_plot)
cmip6_sd0 := tem0[2]
cmip6_sd1 := tem1[2]
cor_first_plot := cor_first_lens2(ind_enhanced_high_lens2)
cor_second_plot := cor_second_lens2(ind_enhanced_high_lens2)
tem0 := bootstrap_stat(cor_first_plot, 0, 10000, 0, False)
tem1 := bootstrap_stat(cor_second_plot, 0, 10000, 0, False)
lens2_mean0 = avg(cor_first_plot)
lens2_mean1 = avg(cor_second_plot)
lens2_sd0 := tem0[2]
lens2_sd1 := tem1[2]

;# 计算79-14间滑动相关的变化趋势
;观测,CMIP部分,CMIP全部,LENS2部分,LENS2全部
year_trend := ispan(1979, 2014, 1)
year_trend_20 := ispan(1979, 2010, 1)
trend_cor_ERA5 := dim_trend(cor_ERA5({year_trend}))
trend_cor_jra55 := dim_trend(cor_jra55({year_trend}))
trend_cor_ncep1 := dim_trend(cor_ncep1({year_trend}))
trend_cor_ncep2 := dim_trend(cor_ncep2({year_trend}))
trend_cor_cfs := dim_trend(cor_cfs({year_trend}))
trend_cor_erai := dim_trend(cor_erai({year_trend}))
trend_cor_cera20c1 := dim_trend(cor_cera20c(0,{year_trend_20}))
trend_cor_cera20c2 := dim_trend(cor_cera20c(1,{year_trend_20}))
trend_cor_cera20c3 := dim_trend(cor_cera20c(2,{year_trend_20}))
trend_cor_cera20c4 := dim_trend(cor_cera20c(3,{year_trend_20}))
trend_cor_cera20c5 := dim_trend(cor_cera20c(4,{year_trend_20}))
trend_cor_cera20c6 := dim_trend(cor_cera20c(5,{year_trend_20}))
trend_cor_cera20c7 := dim_trend(cor_cera20c(6,{year_trend_20}))
trend_cor_cera20c8 := dim_trend(cor_cera20c(7,{year_trend_20}))
trend_cor_cera20c9 := dim_trend(cor_cera20c(8,{year_trend_20}))
trend_cor_cera20c10 := dim_trend(cor_cera20c(9,{year_trend_20}))
; trend_cor_era20c := dim_trend(cor_era20c({year_trend_20}))
;# 观测的趋势
; trends_obs := (/trend_cor_ERA5,trend_cor_jra55,trend_cor_ncep1,trend_cor_ncep2,trend_cor_cfs,trend_cor_erai,trend_cor_cera20c1,trend_cor_cera20c2,trend_cor_cera20c3,trend_cor_cera20c4,trend_cor_cera20c5,trend_cor_cera20c6,trend_cor_cera20c7,trend_cor_cera20c8,trend_cor_cera20c9,trend_cor_cera20c10,trend_cor_20th,trend_cor_era20c/)
; trends_obs = (/trends_obs*10/)
; trends_obs_mean := avg(trends_obs);0.3089146
; trends_obs_mean@n = dimsizes(trends_obs)
; trends_obs_sd := stddev(trends_obs)

; tem0 := bootstrap_stat(trends_obs, 0, 10000, 0, False)
; trends_obs_sd := tem0[2]
; trend_obs_centry = dim_trend(cor_all_mean({1915:2014}))
; trend_obs_centry = (/trend_obs_centry*10/)

; print(trends_obs_mean)
; print(trends_obs_sd)
;模式
trend_cor_CMIP6_high := dim_trend_n(slide_cor_cmip6_enhanced_high(:,{year_trend}),1)
trend_cor_CMIP6_high = (/trend_cor_CMIP6_high*10/)
trend_cor_CMIP6_high_mean := avg(trend_cor_CMIP6_high)
trend_cor_CMIP6_high_mean@n = dimsizes(trend_cor_CMIP6_high)
; trend_cor_CMIP6_high_sd := stddev(trend_cor_CMIP6_high)
tem0 := bootstrap_stat(trend_cor_CMIP6_high, 0, 10000, 0, False)
trend_cor_CMIP6_high_sd := tem0[2]

print("trend_cor_CMIP6_high_mean: "+trend_cor_CMIP6_high_mean)
print("trend_cor_CMIP6_high_sd: "+trend_cor_CMIP6_high_sd)

trend_cor_LENS2_high := dim_trend_n(slide_cor_lens2_enhanced_high(:,{year_trend}),1)
trend_cor_LENS2_high = (/trend_cor_LENS2_high*10/)
trend_cor_LENS2_high_mean := avg(trend_cor_LENS2_high);0.1194309
trend_cor_LENS2_high_mean@n = dimsizes(trend_cor_LENS2_high)
; trend_cor_LENS2_high_sd := stddev(trend_cor_LENS2_high)
tem0 := bootstrap_stat(trend_cor_LENS2_high, 0, 10000, 0, False)
trend_cor_LENS2_high_sd := tem0[2]

print("trend_cor_LENS2_high_mean: "+trend_cor_LENS2_high_mean)
print("trend_cor_LENS2_high_sd: "+trend_cor_LENS2_high_sd)

trend_cor_CMIP6_all := dim_trend_n(slide_cor_cmip6(:,{year_trend}),1)
trend_cor_CMIP6_all = (/trend_cor_CMIP6_all*10/)
trend_cor_CMIP6_all_mean := avg(trend_cor_CMIP6_all)
trend_cor_CMIP6_all_mean@n = dimsizes(trend_cor_CMIP6_all)
; trend_cor_CMIP6_all_sd := stddev(trend_cor_CMIP6_all)
tem0 := bootstrap_stat(trend_cor_CMIP6_all, 0, 10000, 0, False)
trend_cor_CMIP6_all_sd := tem0[2]

print("trend_cor_CMIP6_all_mean: "+trend_cor_CMIP6_all_mean)
print("trend_cor_CMIP6_all_sd: "+trend_cor_CMIP6_all_sd)

trend_cor_LENS2_all := dim_trend_n(slide_cor_lens2(:,{year_trend}),1)
trend_cor_LENS2_all = (/trend_cor_LENS2_all*10/)
trend_cor_LENS2_all_mean := avg(trend_cor_LENS2_all)
trend_cor_LENS2_all_mean@n = dimsizes(trend_cor_LENS2_all)
; trend_cor_LENS2_all_sd := stddev(trend_cor_LENS2_all)
tem0 := bootstrap_stat(trend_cor_LENS2_all, 0, 10000, 0, False)
trend_cor_LENS2_all_sd := tem0[2]

print("trend_cor_LENS2_all_mean: "+trend_cor_LENS2_all_mean)
print("trend_cor_LENS2_all_sd: "+trend_cor_LENS2_all_sd)


;# 计算15-14间滑动相关的变化趋势
year_trend_centry := ispan(1915, 2014, 1)
trend_cor_CMIP6_high_centry := dim_trend_n(slide_cor_cmip6_enhanced_high(:,{year_trend_centry}),1)
trend_cor_CMIP6_high_centry = (/trend_cor_CMIP6_high_centry*10/)
trend_cor_CMIP6_high_centry_mean := avg(trend_cor_CMIP6_high_centry)
trend_cor_CMIP6_high_centry_mean@n = dimsizes(trend_cor_CMIP6_high_centry)
; trend_cor_CMIP6_high_centry_sd := stddev(trend_cor_CMIP6_high_centry)
tem0 := bootstrap_stat(trend_cor_CMIP6_high_centry, 0, 10000, 0, False)
trend_cor_CMIP6_high_centry_sd := tem0[2]

print("trend_cor_CMIP6_high_centry_mean: "+trend_cor_CMIP6_high_centry_mean)
print("trend_cor_CMIP6_high_centry_sd: "+trend_cor_CMIP6_high_centry_sd)

trend_cor_LENS2_high_centry := dim_trend_n(slide_cor_lens2_enhanced_high(:,{year_trend_centry}),1)
trend_cor_LENS2_high_centry = (/trend_cor_LENS2_high_centry*10/)
trend_cor_LENS2_high_centry_mean := avg(trend_cor_LENS2_high_centry);0.1194309
trend_cor_LENS2_high_centry_mean@n = dimsizes(trend_cor_LENS2_high_centry)
; trend_cor_LENS2_high_centry_sd := stddev(trend_cor_LENS2_high_centry)
tem0 := bootstrap_stat(trend_cor_LENS2_high_centry, 0, 10000, 0, False)
trend_cor_LENS2_high_centry_sd := tem0[2]

print("trend_cor_LENS2_high_centry_mean: "+trend_cor_LENS2_high_centry_mean)
print("trend_cor_LENS2_high_centry_sd: "+trend_cor_LENS2_high_centry_sd)

trend_cor_CMIP6_all_centry := dim_trend_n(slide_cor_cmip6(:,{year_trend_centry}),1)
trend_cor_CMIP6_all_centry = (/trend_cor_CMIP6_all_centry*10/)
trend_cor_CMIP6_all_centry_mean := avg(trend_cor_CMIP6_all_centry)
trend_cor_CMIP6_all_centry_mean@n = dimsizes(trend_cor_CMIP6_all_centry)
; trend_cor_CMIP6_all_centry_sd := stddev(trend_cor_CMIP6_all_centry)
tem0 := bootstrap_stat(trend_cor_CMIP6_all_centry, 0, 10000, 0, False)
trend_cor_CMIP6_all_centry_sd := tem0[2]

print("trend_cor_CMIP6_all_centry_mean: "+trend_cor_CMIP6_all_centry_mean)
print("trend_cor_CMIP6_all_centry_sd: "+trend_cor_CMIP6_all_centry_sd)

trend_cor_LENS2_all_centry := dim_trend_n(slide_cor_lens2(:,{year_trend_centry}),1)
trend_cor_LENS2_all_centry = (/trend_cor_LENS2_all_centry*10/)
trend_cor_LENS2_all_centry_mean := avg(trend_cor_LENS2_all_centry)
trend_cor_LENS2_all_centry_mean@n = dimsizes(trend_cor_LENS2_all_centry)
; trend_cor_LENS2_all_centry_sd := stddev(trend_cor_LENS2_all_centry)
tem0 := bootstrap_stat(trend_cor_LENS2_all_centry, 0, 10000, 0, False)
trend_cor_LENS2_all_centry_sd := tem0[2]

print("trend_cor_LENS2_all_centry_mean: "+trend_cor_LENS2_all_centry_mean)
print("trend_cor_LENS2_all_centry_sd: "+trend_cor_LENS2_all_centry_sd)

print(trend_cor_ERA5)
print(trend_cor_CMIP6_high)
print(trend_cor_CMIP6_all)
print(avg(trend_cor_CMIP6_all))
print(trend_cor_LENS2_high)
print(trend_cor_LENS2_all)
print(avg(trend_cor_LENS2_all))

;以两时段的差异为指数
zf_diff = cor_second_cmip6-cor_first_cmip6
print(zf_diff)
method = "clim"
boxL := (/30,55,0,100/)
; boxO := (/15,55,170,230/)
boxO := (/30,55,130,230/)

boxL := (/20,60,0,70/)
boxO := (/15,55,170,230/)
f := addfile("CMIP6_ST_Diff.nc", "r")
; f := addfile("LENS2_ST_Diff.nc", "r")
SST_clim_diff_cmip6 = f->ST
; fout := addfile("CMIP6_ST_Diff.nc", "c")
; fout->ST = SST_clim_diff_cmip6
;# 计算表面气温差异指数
SST_clim_diff_cmip6_flip = lonFlip(SST_clim_diff_cmip6);0..357.5
; SST_clim_diff_cmip6_flip = latWeight(SST_clim_diff_cmip6_flip)
SST_clim_diff_cmip6_zm0 := dim_avg_n_Wrap(SST_clim_diff_cmip6(:,{boxL(0):boxL(1)},{boxL(2):boxL(3)}), (/1,2/))
SST_clim_diff_cmip6_zm1 := dim_avg_n_Wrap(SST_clim_diff_cmip6(:,{boxO(0):boxO(1)},{boxO(2):boxO(3)}), (/1,2/))
SST_clim_diff_cmip6_zm2 := dim_avg_n_Wrap(SST_clim_diff_cmip6(:,{20:60},:), (/1,2/));纬圈平均
;# Fig2a 滑动相关
itemType = "Nature"
rScale = 0.5
opt := True
notDrawAndFrame(opt)
  opt@minmax = (/-0.3,0.65/)
  opt@tmYLValues := (/-0.3,0,0.3,0.6/)
  opt@trXMaxF = 2062
  ; opt@tmXBTickSpacingF = 20
  opt@tmXBTickSpacingF = 50
  opt@tmXBTickStartF = 1910
  opt@gsnXYBarChart = False
  ; opt@gsnYRefLine = -10
  opt@Yref = -10
  opt@xyLineThicknessF = 7
  opt@gsnLeftString = genItem("a",itemType)+"  Evolution of R (WJA, EJA)"
  opt@gsnLeftStringFontHeightF = 0.035
  opt@gsnLeftStringParallelPosF = -0.06
  opt@gsnLeftStringOrthogonalPosF = 0.03
  ; opt@gsnLeftStringParallelPosF = 0.15
  ; opt@gsnRightString = "Simulated evolution of Corr (WAJ, EAJ)"
  ; opt@gsnRightStringFontHeightF = 0.035
  ; opt@gsnRightStringParallelPosF = 1.1
  ; opt@gsnRightStringOrthogonalPosF = 0.015
  opt@tmYLLabelFontHeightF = 0.03
  opt@tmXBLabelFontHeightF = 0.03
  opt@tmXBLabelFontColor = labelColor
  opt@tmYLLabelFontColor = labelColor
  ; opt@tmYLLabelFont = 22
  opt@vpHeightF = 0.5
  opt@tmXTBorderOn = False
  opt@tmYRBorderOn = False
  opt@vpWidthF = 0.9
  opt@tiXAxisString = "Mid-year of 21-yr sliding window"
  ; opt@xyLineColor = "DodgerBlue"
  opt@xyLineColor = cmipColor
  ; opt@tiXAxisFontColor = "Grey29"
  ; opt@tiXAxisOffsetYF = 0.065
  opt@tiXAxisFontHeightF = 0.03
  opt@tiYAxisString = "UDZC"
  opt@tiYAxisOffsetXF = 0.005
  opt@tmYROn = True
  opt@tmYRMajorLineColor = "Firebrick1"
  opt@tmYRLabelsOn = True
  opt@tmYRLabelFontColor = "Firebrick1"
  opt@tmYRValues := (/-0.3,0,0.3,0.6/)
  opt@tmYRLabels = (/"-0.4","0.0","0.4","0.8"/)
  opt@tmYRLabelFontHeightF = 0.025
  opt@tmYRMajorLengthF = 0.01
  opt@tmYRMajorOutwardLengthF = 0
  opt@tmYRMajorThicknessF = 5
  opt@tmYRLabelDeltaF = -1
plot(0) = plot_ts(wks,slide_cor_cmip6_enhanced_high_mean,opt)
;# 背景颜色
pgres := (/-10,10,1900,1998.5/)
  pgres@gsFillOpacityF = 0.05
  pgres@gsFillColor = "#cdcdcd"
; add_fillBox(plot(0),pgres)
pgres = (/-10,10,1998.5,2065/)
  ; pgres@gsFillOpacityF = 0.05
  ; pgres@gsFillOpacityF = 0.15
  ; pgres@gsFillColor = "Grey"
  pgres@tfPolyDrawOrder = "PreDraw"
  ; pgres@gsFillColor = "#4EA250"
  pgres@gsFillOpacityF = 0.1
  pgres@gsFillColor = bgColor
add_fillBox(plot(0),pgres)
; yref := 0
;   yref@polyYRefMax = 2010
; add_Yref(plot(0),yref)
  ; opt@xyLineColor = "Firebrick1"
  opt@xyLineColor = lens2Color
add_ts(plot(0),slide_cor_lens2_enhanced_high_mean,opt)
; add_fillBox(plot(0),box)
rshade := True
  rshade@gsFillOpacityF = 0.15
  ; rshade@gsFillColor = "#badcfe"
  rshade@gsFillColor = "#72da6d"
print("addSpreading")
addSpreading(plot(0),slide_cor_cmip6_enhanced_high,rshade)
  ; rshade@gsFillOpacityF = 1
  ; rshade@gsFillColor = "#ffbeb8"
  rshade@gsFillColor = "#deacea"
  ; rshade@gsFillOpacityF = 1.0
print("addSpreading")
addSpreading(plot(0),slide_cor_lens2_enhanced_high,rshade)
  opt@xyLineColor = "Firebrick1"
  opt@xyLineThicknessF = 10
  cor_all_mean = (/cor_all_mean*0.75/)
add_ts(plot(0),cor_all_mean,opt)
print("addSpreading")
  rshade@gsFillOpacityF = 0.2
  rshade@gsFillColor = "#ff0000"
  part_cor_all = (/part_cor_all*0.75/)
addSpreading(plot(0),part_cor_all,rshade)

dimCMIP6 = dimsizes(slide_cor_cmip6_enhanced_high)
dimLENS2 = dimsizes(slide_cor_lens2_enhanced_high)
text := "CMIP6 ("+dimCMIP6(0)+")"
  text@txFontHeightF = 0.025
  text@txFontColor = cmipColor
  text@txFont = 21
  text@txJust = "CenterLeft"
add_text(plot(0),text,1914,0.6)
text = "LENS2 ("+dimLENS2(0)+")"
  text@txFontColor = lens2Color
; add_text(plot(0),text,1950,0.6)
add_text(plot(0),text,1914,0.5)
  text@txFontHeightF = 0.025
; text = "Observation (multi-source mean)"
text = "Reanalysis (multi-source mean)"
  text@txFontColor = "Firebrick1"
add_text(plot(0),text,1914,0.4)

;# fig1a右 模式
color0 = "#0673BA"
; colorBorder0 = "#06AEEB"
color1 = "#DB5527"
; colorBorder1 = "#ff6a00"
barOffsetXF = 0.17
means0 := (/cmip6_mean0,lens2_mean0/)
; setDim(means0,dim,dimName,coord)
means1 := (/cmip6_mean1,lens2_mean1/)
means0@barOffsetXF = -barOffsetXF
; means0@barBorderColor = colorBorder0
means0@barBorderThicknessF = 10
means0@gsnXYBarChartBarWidth = 0.3
; means0@gsnXYBarChartOutlineThicknessF = 10
means0@gsnAboveYRefLineColor = color0
means0@gsnBelowYRefLineColor = color0
means1@barOffsetXF = barOffsetXF
; means1@barBorderColor = colorBorder1
means1@barBorderThicknessF = 4
means1@gsnXYBarChartBarWidth = 0.3
; means1@gsnAboveYRefLineColor = "#e04f4b"
; means1@gsnAboveYRefLineColor = "#e94e41"
; means1@xyLineThicknessF = 10
; delete(means1@xyLineColor)
; delete(means1@xyLineThicknessF)
means1@gsnAboveYRefLineColor = color1
means1@gsnBelowYRefLineColor = color1
opt := True
notDrawAndFrame(opt)
  opt@trYMaxF = 0.63
  opt@trYMinF = 0
  opt@trXMaxF = 1.6
  opt@trXMinF = 0.5
  opt@gsnLeftString = ""
  opt@gsnLeftStringFontHeightF = 0.035
  opt@gsnLeftStringOrthogonalPosF = 0.02
  opt@tmYLBorderOn = False
  opt@tmXTBorderOn = False
  ; opt@gsnLeftStringParallelPosF = -0.15
  ; opt@gsnRightString = "CESM2-LE"
  ; opt@gsnRightStringFontHeightF = 0.02
  ; opt@gsnRightStringOrthogonalPosF = 0.05
  ; opt@tiYAxisString = "Correlation"
  ; opt@tiYAxisFontHeightF = 0.02
  opt@tmYLFormat = "0@;*.1f"
  opt@tmYLLabelFontHeightF = 0.03
  opt@tmXBLabelFontHeightF = 0.03
  opt@tmXBLabelDeltaF = -0.5
  opt@tmXBMajorLengthF = 0.01
  opt@tmXBMajorOutwardLengthF = 0.01
  opt@tmYLMajorLengthF = 0.01
  opt@tmYLMajorOutwardLengthF = 0.01
  opt@tmYLTickSpacingF = 0.2
  opt@tmYROn = True
  opt@tmYRLabelsOn = True
  ; opt@tmYRTickSpacingF = 0.2
  ; opt@tmYRMode = "Explicit"
  ; opt@tmYRValues = (/0.0,0.2,0.4/)
  opt@tmYLOn = False
  opt@tmBorderThicknessF = 5
  opt@vpHeightF = 0.5
  opt@vpWidthF = 0.33
  opt@tmXBLabels = (/"",""/)
  opt@tmXBLabelFontColor = "red"
  opt@tmXBLabelFont = 22
  opt@tmYLLabelFontColor = labelColor
  ; opt@tmBorderLineColor = "DodgerBlue"
  ; opt@tmXBMajorLineColor = "DodgerBlue"
  ; opt@tmYLMajorLineColor = "DodgerBlue"
  ; opt@tmYLLabelFontColor = "DodgerBlue"
  ; opt@tfPolyDrawOrder = "PostDraw"
  ; opt@tmXBLabelFontColor = "DodgerBlue"
  ; opt@tmXBLabels = models
plot(1) = plot_bar(wks,means0,opt)
add_bar(plot(1),means1)
text := "CMIP6"
  text@txFont = 21
  text@txFontColor = cmipColor
  text@txFontHeightF = 0.027
add_string(plot(1),text,0.24,0.0)
text = "LENS2"
  text@txFontColor = lens2Color
add_string(plot(1),text,0.71,0.0)


; pgres := (/-10,10,0,3/)
;   pgres@gsFillOpacityF = 0.1
;   pgres@gsFillColor = "DodgerBlue"
;   pgres@tfPolyDrawOrder = "PreDraw"
; add_fillBox(plot(1),pgres)

opt@barOffsetXF = -barOffsetXF
opt@gsLineThicknessF = 5.
opt@barWidth = 0.1
; opt@gsLineColor = "DodgerBlue"
add_errorBar(plot(1),1,cmip6_mean0+cmip6_sd0,cmip6_mean0-cmip6_sd0,opt)
opt@barOffsetXF = barOffsetXF
add_errorBar(plot(1),1,cmip6_mean1+cmip6_sd1,cmip6_mean1-cmip6_sd1,opt)
opt@barOffsetXF = -barOffsetXF
add_errorBar(plot(1),2,lens2_mean0+lens2_sd0,lens2_mean0-lens2_sd0,opt)
opt@barOffsetXF = barOffsetXF
add_errorBar(plot(1),2,lens2_mean1+lens2_sd1,lens2_mean1-lens2_sd1,opt)

; box := "1920-1990"
box := "1900-1970"
  box@txJust = "CenterLeft"
  box@txFontHeightF = 0.025
  box@gsFillColor = color0
  box@txOffsetXF := 0.25
  ; box@txOffsetXF = 10
  box@gsClipOn = False
; add_box(plot(2),2050,0.75,15,0.07,box)
add_box(plot(1),1.,0.61,0.3,0.028,box)
box = "2000-2070"
  box@txOffsetXF := 0.25
  box@gsFillColor = color1
; add_box(plot(1),1.4,0.475,0.3,0.035,box)
add_box(plot(1),1.,0.56,0.3,0.028,box)
box = ""
  box@gsFillColor = "Grey"
  ; box@tfPolyDrawOrder = "PostDraw"
; add_box(plot(1),2.3,0.47,1,0.5,box)
; rts := True
;   rts@txFontHeightF = 
; gsn_text_ndc(wks, "1900-1970", 0.3, 0.3, rts)

;趋势柱状图
;# fig1b 模式
; ; color0 = "#88d5f1"
; ; colorBorder0 = "#06AEEB"
; ; color1 = "#f99045"
; ; colorBorder1 = "#ff6a00"
; means0 := (/trends_obs_mean,trend_cor_LENS2_high_mean,trend_cor_LENS2_all_mean,trend_cor_CMIP6_high_mean,trend_cor_CMIP6_all_mean/)
; ; setDim(means0,dim,dimName,coord)
; ; means0@barBorderColor = colorBorder0
; means0@barBorderThicknessF = 7
; means0@gsnXYBarChartBarWidth = 0.25
; ; means0@gsnXYBarChartOutlineThicknessF = 10
; means0@gsnAboveYRefLineColor = color1
; means0@gsnBelowYRefLineColor = color1
; means0@barOffsetXF = -0.14
; opt := True
; notDrawAndFrame(opt)
;   opt@trYMaxF = 0.36
;   opt@trYMinF = -0.05
;   opt@trXMaxF = 4.7
;   opt@trXMinF = 0.3
;   opt@vpXF = 0.15
;   opt@gsnLeftString = genItem("b",itemType)+"  Trend in UDZC"
;   opt@gsnLeftStringFontHeightF = 0.035
;   opt@gsnLeftStringOrthogonalPosF = 0.02
;   opt@gsnLeftStringParallelPosF = -0.06
;   opt@tmYLBorderOn = True
;   opt@tmYRBorderOn = False
;   opt@tmXTBorderOn = False
;   ; opt@gsnLeftStringParallelPosF = -0.15
;   opt@gsnRightString = ""
;   ; opt@gsnRightStringFontHeightF = 0.02
;   opt@gsnRightStringOrthogonalPosF = 0.05
;   opt@tiYAxisString = "Trend (decade~S~-1~N~)"
;   opt@tiYAxisFontHeightF = 0.03
;   opt@tmYLFormat = "0@;*.1f"
;   opt@tmYLLabelFontHeightF = 0.03
;   opt@tmYLLabelFontColor = labelColor
;   opt@tmYLLabelDeltaF = -0.5
;   opt@tmXBLabelFontHeightF = 0.03
;   opt@tmXBLabelDeltaF = -0.1
;   opt@tmXBMajorLengthF = 0.01
;   opt@tmXBMajorOutwardLengthF = 0.01
;   opt@tmYLMajorLengthF = 0.01
;   opt@tmYLMajorOutwardLengthF = 0.01
;   opt@tmYLMajorThicknessF = 10
;   opt@tmYLTickSpacingF = 0.1
;   opt@tmYLTickStartF = 0
;   opt@tmYROn = False
;   opt@tmYUseLeft = False
;   opt@tmYRValues = (/0,0.15,0.3/)
;   opt@tmYRLabels = (/"0.0","0.03","0.06"/)
;   opt@tmYRLabelFontHeightF = 0.03
;   opt@tmYRLabelDeltaF = -0.3
;   opt@tmYRMode = "Explicit"
;   opt@tmYRMinorOn = False
;   opt@tmYRLabelsOn = True
;   opt@tmYRMajorThicknessF = 10
;   ; opt@tmYRTickSpacingF = 0.2
;   ; opt@tmYRMode = "Explicit"
;   ; opt@tmYRValues = (/0.0,0.2,0.4/)
;   opt@tmYLOn = True
;   opt@tmBorderThicknessF = 5
;   opt@vpHeightF = 0.6
;   opt@vpWidthF = 1.
;   opt@tmXBLabels = (/"~F22~Obs~F21~~C~ ","~F22~  LENS2~F21~~C~(selected)","~F22~LENS2~F21~~C~   (all)","~F22~  CMIP6~F21~~C~(selected)","~F22~CMIP6~F21~~C~   (all)"/)
;   ; opt@tmXBLabelFontColor =#00000001"
;   ; opt@tmXBLabelFont = 22
;   ; opt@tmXBLabelAngleF = -20
;   opt@tmXBLabelJust = "CenterCenter"
;   opt@gsnYRefLineDashPattern = 2
;   opt@gsnYRefLine = 0
;   ; opt@tmYLLabelFontColor = "#0673BA"
;   ; opt@tmYLMajorLineColor = "#0673BA"
;   ; opt@tmYRLabelFontColor = "#DB5527"
;   ; opt@tmYRMajorLineColor = "#DB5527"
;   opt@tmYRLabelDeltaF = -0.5
;   ; opt@tmYLLabelFont = 22
;   ; opt@tmBorderLineColor = "DodgerBlue"
;   ; opt@tmXBMajorLineColor = "DodgerBlue"
;   ; opt@tmYLMajorLineColor = "DodgerBlue"
;   ; opt@tmYLLabelFontColor = "DodgerBlue"
;   ; opt@tfPolyDrawOrder = "PostDraw"
;   ; opt@tmXBLabelFontColor = "DodgerBlue"
;   ; opt@tmXBLabels = models
; plot(3) = plot_bar(wks,means0,opt)
;   opt@barOffsetXF = -0.14
;   opt@barWidth = 0.08

; ; errorBarRange = (/trends_obs_mean+trends_obs_sd,trends_obs_mean-trends_obs_sd/)
; ; add_errorBar(plot(3),1,errorBarRange(0),errorBarRange(1),opt)
; errorBarRange = (/trend_cor_LENS2_high_mean+trend_cor_LENS2_high_sd,trend_cor_LENS2_high_mean-trend_cor_LENS2_high_sd/)
; add_errorBar(plot(3),2,errorBarRange(0),errorBarRange(1),opt)
; errorBarRange = (/trend_cor_LENS2_all_mean+trend_cor_LENS2_all_sd,trend_cor_LENS2_all_mean-trend_cor_LENS2_all_sd/)
; add_errorBar(plot(3),3,errorBarRange(0),errorBarRange(1),opt)
; errorBarRange = (/trend_cor_CMIP6_high_mean+trend_cor_CMIP6_high_sd,trend_cor_CMIP6_high_mean-trend_cor_CMIP6_high_sd/)
; add_errorBar(plot(3),4,errorBarRange(0),errorBarRange(1),opt)
; errorBarRange = (/trend_cor_CMIP6_all_mean+trend_cor_CMIP6_all_sd,trend_cor_CMIP6_all_mean-trend_cor_CMIP6_all_sd/)
; add_errorBar(plot(3),5,errorBarRange(0),errorBarRange(1),opt)

; means0 := (/trend_obs_centry,trend_cor_LENS2_high_centry_mean,trend_cor_LENS2_all_centry_mean,trend_cor_CMIP6_high_centry_mean,trend_cor_CMIP6_all_centry_mean/)
; ; setDim(means0,dim,dimName,coord)
; ; means0@barBorderColor = colorBorder1
; means0@barBorderThicknessF = 5
; means0@gsnXYBarChartBarWidth = 0.25
; means0@barOffsetXF = 0.14
; ; means0@gsnXYBarChartOutlineThicknessF = 10
; means0@gsnAboveYRefLineColor = color0
; means0@gsnBelowYRefLineColor = color0
; add_bar(plot(3),means0)
;   opt@barOffsetXF = 0.14
; add_errorBar(plot(3),2,trend_cor_LENS2_high_centry_mean+trend_cor_LENS2_high_centry_sd,trend_cor_LENS2_high_centry_mean-trend_cor_LENS2_high_centry_sd,opt)
; add_errorBar(plot(3),3,trend_cor_LENS2_all_centry_mean+trend_cor_LENS2_all_centry_sd,trend_cor_LENS2_all_centry_mean-trend_cor_LENS2_all_centry_sd,opt)
; add_errorBar(plot(3),4,trend_cor_CMIP6_high_centry_mean+trend_cor_CMIP6_high_centry_sd,trend_cor_CMIP6_high_centry_mean-trend_cor_CMIP6_high_centry_sd,opt)
; add_errorBar(plot(3),5,trend_cor_CMIP6_all_centry_mean+trend_cor_CMIP6_all_centry_sd,trend_cor_CMIP6_all_centry_mean-trend_cor_CMIP6_all_centry_sd,opt)

; ; box := "1920-1990"
; box := "1979-2014"
;   box@txJust = "CenterLeft"
;   box@txFontHeightF = 0.025
;   box@gsFillColor = color1
;   box@txOffsetXF := 0.2
;   ; box@txOffsetXF = 10
;   box@gsClipOn = False
; ; add_box(plot(3),2050,0.75,15,0.07,box)
; add_box(plot(3),4.3,0.35,0.3,0.018,box)
; box = "1915-2014"
;   box@txOffsetXF := 0.2
;   box@gsFillColor = color0
; ; add_box(plot(1),1.4,0.475,0.3,0.035,box)
; add_box(plot(3),4.3,0.31,0.3,0.018,box)

model_index := ispan(0, dimsizes(models)-1, 1)
model_index := pop(model_index,(/10,13,14,15,17,29,32,30/))
; print(model_index)
ts := cor_second_cmip6(model_index)
; SST_clim_cor := escorc_n(ts, SST_clim_diff_cmip6(model_index,:,:), 0, 0)
SST_clim_cor := escorc_n(ts, SST_clim_diff_cmip6(model_index,:,:), 0, 0)
SST_clim_cor_tval = R2t(SST_clim_cor,dimsizes(ts)-2)
res_fdr = True
  res_fdr@df = dimsizes(ts)-2
  res_fdr@sigLevel = 90
sig_tval = getSigLevel(SST_clim_cor_tval,res_fdr)

copy_VarCoords(SST_clim_diff_cmip6(0,:,:), SST_clim_cor)
sig_r = sig_tval/sqrt(dimsizes(ts)-2+sig_tval^2)
; SST_clim_future_cor := escorc_n(ts, SST_clim_future_cmip6, 0, 0)

range := (/-45,85,-15,345/)

; range := (/0,90,0,360/)
;# fig.6b
opt := True
  opt@vpWidthF = 1.3
  opt@vpHeightF = 0.5
  ; opt@gsnLeftString = "~F22~c~F21~   "+(/"Future warming amplitude linked to future zonal uniformity","u200"/)
  ; opt@gsnLeftString = "~F22~c~F21~   "+(/"Mid-latitude warming favors strong zonal uniformity","u200"/)
  opt@gsnLeftString = genItem("b",itemType)+"  "+"Inter-model R (future UDZC, future warming)"
  opt@gsnLeftStringParallelPosF = -0.048
  opt@gsnLeftStringOrthogonalPosF = 0.035
  opt@gsnLeftStringFontHeightF = 0.035
  opt@tiYAxisString = "Latitude"
  opt@tiYAxisFontHeightF = 0.03
  opt@tiYAxisOffsetXF = -0.01
  opt@tiXAxisString = "Longitude"
  opt@tiXAxisFontHeightF = 0.03
  opt@tiXAxisOffsetYF = 0.045
  ; opt@gsnRightString = (/"2000-2070 minus 1900-1970"/)
  ; opt@gsnRightStringFontHeightF = 0.03
  ; opt@gsnRightStringParallelPosF = 1.2
  ; opt@gsnRightStringOrthogonalPosF = 0.04
  opt@tmXBTickSpacingF = 60
  opt@tmYLTickSpacingF = 40
  opt@tmXBLabelFontHeightF = 0.03
  opt@tmXBLabelFontColor = labelColor
  opt@tmYLLabelFontHeightF = 0.03
  opt@tmYLLabelFontColor = labelColor
  ; opt@mpGeophysicalLineColor = "#78CFD5"
  ; opt@mpProjection = "Robinson"
  ; opt@mpPerimOn = False
  ; opt@mpLimitMode = "LatLon"
  ; opt@mpMinLatF := -60
  ; opt@mpGridAndLimbOn = True
  ; opt@mpGridLatSpacingF = 30
  ; opt@mpGridLonSpacingF = 60
notDrawAndFrame(opt)
plot(3) = plot_base(wks,range,opt)




t := t_value(dimsizes(model_index)-2)
opt := True
notDrawAndFrame(opt)
  opt@lbLabelBarOn = True
  opt@pmLabelBarWidthF = 0.55
  opt@pmLabelBarHeightF = 0.1
  opt@pmLabelBarOrthogonalPosF = 0.25
  opt@pmLabelBarParallelPosF = 0.5
  opt@lbLabelFontHeightF = 0.014
  opt@lbTitleString = "Correlation"
  
  opt@lbTitlePosition = "Right"
  opt@lbTitleFontHeightF = 0.014
  opt@lbTitleDirection = "Across"
  opt@lbOrientation = "Horizontal"
  opt@gsnAddCyclic = True
  ; opt@cnLevels = (/-10,-8,-6,-4,10,15,20,25/)
  ; opt@cnLevels = (/-5,0,5,10,15,20,25,30/)
  ; opt@cnLevels = (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)
  opt@cnFillColors = (/"#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  opt@cnLevels = (/-t@r90,t@r90,t@r95,0.45,0.55/)
  ; opt@cnLevels = (/-t@r90,t@r90,t@r95,0.4,0.5/)
  ; opt@pmLabelBarOrthogonalPosF = 0.1
  ; opt@Scale = 0.1
add_cn(plot(3),SST_clim_cor ,range,opt)

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 7.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
add_topo(plot(3),(/10,50,40,120/),3000,res_topo)

  opt@cnLevel := sig_r
  opt@cnFillScaleF = 1.0
  ; opt@hatchingColor = "#a063c7"
  opt@hatchingColor = "#0673BA"
add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; add_hatching(plot(3),SST_clim_cor,range,opt)
; boxL := (/20,60,0,70/)
; box := (/20,65,-10,129/)
  boxL@gsLineThicknessF = 15
  boxL@gsLineColor = "Tomato"
  ; box@
add_lineBox(plot(3),boxL)
; boxO = (/35,65,236,270/)
; add_lineBox(plot(3),box)
; box = (/65,82,305,334/)
; add_lineBox(plot(3),box)
  boxO@gsLineThicknessF = 15
  boxO@gsLineColor = "DodgerBlue"
; boxO = (/15,55,170,230/)
; box = (/10,60,131,234/)
add_lineBox(plot(3),boxO)
; boxO = (/15,50,281,334/)

; add_lineBox(plot(3),box)

;# fig.6c,e 散点图
colors := (/"blue","green","red","turquoise1","darkorchid1","yellow","orange",\
  "mediumspringgreen","navajowhite","mistyrose","mediumorchid1","mediumpurple","maroon3","magenta2",\
  "olivedrab1","orange2","pink","paleturquoise1","skyblue1","palegreen","tan1",\
  "blue","green","red","turquoise1","darkorchid1","yellow","orange",\
  "mediumspringgreen","navajowhite","mistyrose","mediumorchid1","mediumpurple","maroon3","magenta2",\
  "olivedrab1","orange2","pink","paleturquoise1","skyblue1","palegreen","tan1"/)

colors2 := (/"black","black","black","black","black","black","black",\
           "red","red","red","red","red","red","red",\
           "blue","blue","blue","blue","blue","blue","blue",\
          "black","black","black","black","black","black","black",\
           "red","red","red","red","red","red","red",\
           "blue","blue","blue","blue","blue","blue","blue"/)
nft = newFilledTriangle(wks)
; nfs = newFilledSquare(wks)
nfp = newFilledPentagram(wks)
nhc = newHollowCross(wks)
; plot := newPlots(2)
opt := True
notDrawAndFrame(opt)
  opt@trXMinF = -0.3
  opt@trXMaxF = 0.7
  opt@trYMinF = 1
  opt@trYMaxF = 5.5
  opt@opRegLine = True
  opt@xyMarkerColors := colors
  opt@xyMarkerThicknessF = 10
  ; opt@xyMarkers = (/16,16,16,16,16,16,16,16,16,16,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nfs,nfs,nfs,nfs,nfs,nfs,nfs,nfs,nfs,nfs,4,4,4,4,4,4,4,4,4,4,12,12,12,12,12,12,12,12,12,12/)
  opt@xyMarkers = (/16,16,16,16,16,16,16,16,16,16,16,16,16,16,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft/)
  opt@xyMarkerSizeF = 0.02
  opt@tiXAxisString = "future UDZC"
  opt@tiXAxisFontHeightF = 0.03
  opt@tiYAxisString = "Wariming amplitude (K)"
  opt@tiYAxisFontHeightF = 0.03
  opt@tmYLLabelFontHeightF = 0.03
  opt@tmYLLabelFontColor = labelColor
  opt@tmXBLabelFontHeightF = 0.03
  opt@tmXBLabelFontColor = labelColor
  ; opt@tmXBLabels = 
  opt@gsnLeftString = genItem("c",itemType)+"  Land (red box)"
  opt@gsnLeftStringFontHeightF = 0.035
  opt@gsnLeftStringOrthogonalPosF = 0.03
  opt@gsnLeftStringParallelPosF = -0.09
  opt@vpHeightF = 0.5
  opt@vpWidthF = 0.55
  opt@xyMarkerSizeF = 0.015
  opt@gsnYRefLine = avg(SST_clim_diff_cmip6_zm0(model_index))
  opt@gsnXRefLine = avg(cor_second_cmip6(model_index))
  opt@gsnYRefLineDashPattern = 1
  opt@gsnXRefLineDashPattern = 1
  opt@tmXBMode = "Explicit"
  opt@tmXBValues = (/-0.2,0,0.2,0.4,0.6/)
  opt@tmXBLabels = (/"-0.2","0","0.2","0.4","0.6"/)
  ; opt@xyMarkers = (//)
  ; opt@xymco
plot(4) = scatter(wks,cor_second_cmip6(model_index),SST_clim_diff_cmip6_zm0(model_index),opt)
  R = escorc(cor_second_cmip6(model_index), SST_clim_diff_cmip6_zm0(model_index))
text := "R = "+sprintf("%0.2f", R)+", "+r2pStringDev(R,dimsizes(cor_second_cmip6)-2)
  text@txFontHeightF = 0.03
  text@txJust = "CenterLeft"
  text@txFontColor = "Firebrick1"
add_text(plot(4),text,-0.25,5.2)
  opt@trYMaxF := 3.4
  opt@trYMinF := 0.5
  ; opt@tiYAxisString = ""
  ; opt@tmYLLabelsOn = False
  opt@gsnLeftString = genItem("d",itemType)+"  Ocean (blue box)"
  opt@gsnYRefLine = avg(SST_clim_diff_cmip6_zm1(model_index))
  ; opt@tiXAxisOffsetYF = 0.247
  ; opt@gsnLeftStringParallelPosF = 0
plot(5) = scatter(wks,cor_second_cmip6(model_index),SST_clim_diff_cmip6_zm1(model_index),opt)
  R = escorc(cor_second_cmip6(model_index), SST_clim_diff_cmip6_zm1(model_index))
text = "R = "+sprintf("%0.2f", R)+", "+r2pStringDev(R,dimsizes(cor_second_cmip6)-2)
  text@txFontHeightF = 0.03
add_text(plot(5),text,-0.25,3.2)

  opt@xyMarkers = (/4,4,4,4,4,4,4,4,4,4,4,4,4,4,12,12,12,12,12,12,12,12,12,12,12,12,12,12,7,7,7,7,7,7,7,7,7,7,7,7,7,7/)
  opt@xyMarkerColors := colors2
  opt@xyMarkerThicknessF = 4
  opt@xyMarkerSizeF = 0.02
  opt@gsnLeftString = ""
  opt@gsnXRefLineColor = "transparent"
  opt@gsnYRefLineColor = "transparent"

  ; delete(opt@gsnXRefLine)
  ; delete(opt@gsnYRefLine)
plot_o0 = scatter(wks,cor_second_cmip6(model_index),SST_clim_diff_cmip6_zm0(model_index),opt)
overlay(plot(4), plot_o0)
plot_o1 = scatter(wks,cor_second_cmip6(model_index),SST_clim_diff_cmip6_zm1(model_index),opt)
overlay(plot(5), plot_o1)


;# 组图
resp := True
  resp@gsnFrame = False
  resp@gsnPanelXF = (/0.05,0.341,0.53,0.05,0.53,0.53/)
  resp@gsnPanelYF = (/0.9,0.9,0.9,0.66,0.9,0.66/)
  resp@gsnPanelScaleF = (/0.3,0.3,0.3,0.3,0.3,0.3/)
gsn_panel(wks, plot, (/2,3/), resp)

;# 最右边模式名
rmarker := True
  rmarker@vpWidthF = 1.9
  rmarker@vpHeightF = 2.4
  rmarker@tmXBOn = False
  rmarker@tmYLOn = False
  rmarker@tmXTOn = False
  rmarker@tmYROn = False
  rmarker@tmXBBorderOn = False
  rmarker@tmXTBorderOn = False
  rmarker@tmYLBorderOn = False
  rmarker@tmYRBorderOn = False
notDrawAndFrame(rmarker)
models_plot := models(model_index)
plot := gsn_csm_blank_plot(wks, rmarker)
models_plot@txFontHeightF = 0.019
models_plot@txJust = "CenterLeft"
models_plot@txLineHeightF = 0.0145
txHeight = 0.93
add_string(plot,models_plot,0.05,txHeight)
; add_string(plot,models_plot(:9),0.06,txHeight)
; add_string(plot,models_plot(10:19),0.25,txHeight)
; add_string(plot,models_plot(20:29),0.44,txHeight)
; add_string(plot,models_plot(30:39),0.63,txHeight)
; add_string(plot,models_plot(40:49),0.82,txHeight)
markers_fill := new(50, graphic)
markers_hollw := new(50, graphic)
rmarker := True
; notDrawAndFrame(rmarker)
i = 0
initY = 0.925
MarkerY := initY
markerX := 0.03
markers0 := (/16,16,16,16,16,16,16,16,16,16,16,16,16,16,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nfp,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft,nft/)
markers1 = (/4,4,4,4,4,4,4,4,4,4,4,4,4,4,12,12,12,12,12,12,12,12,12,12,12,12,12,12,7,7,7,7,7,7,7,7,7,7,7,7,7,7/)
do i = 0,dimsizes(models_plot)-1
  rmarker@gsMarkerIndex = markers0(i)
  ; print(i)
  rmarker@gsMarkerColor = colors(i)
  rmarker@gsMarkerSizeF = 0.005
  rmarker@gsMarkerThicknessF = 10.
  ; print("X: "+markerX+"; Y: "+MarkerY)
  markers_fill(i) = gsn_add_polymarker(wks, plot, markerX, MarkerY, rmarker)
  MarkerY = MarkerY - models_plot@txLineHeightF +0.00002
  ; if(MarkerY .le. 0)
  ;   MarkerY = 0.935
  ;   markerX = markerX+0.19
  ; end if
  ; markerX = OriginalMarkerX + 0.1*(i/10)
end do
MarkerY := initY
markerX := 0.03
do i = 0, dimsizes(models_plot)-1
  rmarker@gsMarkerColor = colors2(i)
  rmarker@gsMarkerIndex = markers1(i)
  rmarker@gsMarkerThicknessF = 4.
  rmarker@gsMarkerSizeF = 0.007
  markers_hollw(i) = gsn_add_polymarker(wks, plot, markerX, MarkerY, rmarker)
  MarkerY = MarkerY - models_plot@txLineHeightF +0.00002
end do
resp := True
  resp@gsnFrame = False
  resp@gsnPanelScaleF = 0.3
  resp@gsnPanelXF = 0.7
  resp@gsnPanelYF = 0.95
gsn_panel(wks, plot, (/1,1/), resp)
frame(wks)
delete(wks)
system("gs -q -sDEVICE=png16m -sBATCH -sOutputFile="+fileName+".png -dNOPAUSE -r200 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "+fileName+".pdf")
show("/home/llf/code/ncl/EurasianJet/UDZS_Code/"+fileName+".png")
end