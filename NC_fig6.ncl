load "indices.ncl"
begin

  pdf = "pdf"
    pdf@wkPaperWidthF = 60
    pdf@wkPaperHeightF = 60

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



; 计算 SVD
range := (/40,80,-50,14/)
; LRange = (/35,70,-20,15/)
LRange = (/35,80,-20,25/)
; LRange = (/15,75,-50,25/)
RRange = (/25,80,-20,140/)
useCache = True
if(useCache .and. fileexists("SVD.nc"))then
  f = addfile("SVD.nc", "r")
  ts_left = f->l
  ts_right = f->r
else
  type = "SST"
    type@month := (/2,3,4,5,6,7,8/)
    type@year  := year2
    type@source = "ersstv5"
    type@range := LRange
  opt = "anom"

  opt = "none"
    opt@std = True
  SST := process(type,opt)
  SST@sqrt = True
  SST := dim_standardize_n_Wrap(SST, 0, 0)
  SST := latWeight(SST)
  dim_sst := dimsizes(SST)
  SST_anom := dim_rmvmean_n_Wrap(SST, 0)
  print(dim_sst)
  printVarSummary(SST_anom)
  SST_re := reshape(SST_anom, (/dim_sst(0),dim_sst(2),dim_sst(1)*dim_sst(3)/))
  setDim(SST_re,0,"year",year2)
  ; printVarSummary(SST_re)
  ; exit()
  type = "u"
    type@level = 200
    type@source = "jra55"
    type@month := (/7,8/)
    type@range := RRange
  opt = "anom"
  U200 := process(type,opt)
  U200 := dim_standardize_n_Wrap(U200, 0, 0)
  U200@sqrt = True
  U200 := latWeight(U200)
  svd_results = SVD(SST_re,U200,opt)
  ts_left = svd_results[0](0,:)
  ts_right = svd_results[1](0,:)
  pvar = svd_results[3]
  system("rm SVD.nc")
  fout = addfile("SVD.nc","c")
  fout->l = ts_left
  fout->r = ts_right
end if


ts0 = ts_left;SST
ts0 = (/ts_left/)
ts1 = ts_right;U200
ts1 = (/ts_right/)
; print(stddev(ts0))
; print(stddev(ts1))
; exit()

;# 计算和EOF的空间相关系数
method = "anom"
type = "u"
  type@source = "ERA5"
  type@range = (/20,65,0,150/)
  type@year := ispan(1999, 2022, 1)
  type@level = 200
  type@month = (/7,8/)
U200 := process(type,method)

printVarSummary(EOF1_p2)
printVarSummary(U200)
rec_PC1 = escorc_n(EOF1_p2, U200, 0, 0)
rec_EMCA_U200 = escorc_n(ts1, U200, 0, 0)
pr = pattern_cor(rec_PC1, rec_EMCA_U200, 1.0, 0)
print(pr)
; exit()

;# 画图部分
itemType = "NC"
fileName = "NC_fig6"
fig2png = "png"
  fig2png@wkHeight = 4096
  fig2png@wkWidth = 4096
wks := gsn_open_wks(pdf,fileName)

;# 底图
size := 7
  size@gsnLeftString = (/genItem("b",itemType)+"  U200 JA",genItem("A",itemType)+"  SST",genItem("C",itemType)+"   U200 & V200 & WAF",genItem("D",itemType)+"  SST"/)
  size@gsnLeftStringParallelPosF = 0.001
  size@gsnLeftStringFontHeightF = 0.035
  size@gsnLeftStringOrthogonalPosF = 0.03
  ; size@gsnRightString = "1 m~S~-2~N~ s~S~-2~N~"
  ; size@gsnRightStringFontHeightF = 0.02
  ; size@gsnRightStringOrthogonalPosF = -0.03
  ; size@gsnRightStringParallelPosF = 0.98
  size@gsnMaskLambertConformal = True
  size@gsnCenterString = "~F22~"+(/"EMCA1 (SST, U200)","EMCA1-U200","EMCA1-SST","EMCA1-SST"/)
  size@gsnCenterStringFontHeightF = 0.04
  size@gsnCenterStringParallelPosF = -0.3
  size@gsnCenterStringOrthogonalPosF = 0.15
  size@mpGridAndLimbOn = False
  size@mpGridLatSpacingF = 30
  size@mpGridLonSpacingF = 30
  size@mpGridLineDashPattern := 2
  size@vpHeightF = 0.7
  size@vpWidthF = 0.9
  size@polar = True
  size@mpCenterLonF = 70
  size@mpGeophysicalLineColor = "#78CFD5"
  size@mpGeophysicalLineThicknessF = 5
  size@gsnPolarLabelFontHeightF = 0.02
  size@gsnPolarLabelSpacing = 120
; range = (/10,85,-30,180/)
range = (/25,85,-100,40/)
plot := plot_bases(wks,range,size)
opt := True
notDrawAndFrame(opt)
  opt@gsnLeftString = "FM"
  opt@gsnLeftStringFontHeightF = 0.055
  opt@gsnLeftStringParallelPosF = 0
  opt@gsnLeftStringOrthogonalPosF = 0.02
  opt@vpHeightF = 0.64
  opt@vpWidthF = 0.68
  opt@tmXBLabelFontHeightF = 0.02
  opt@tmYLLabelFontHeightF = 0.02

  opt@mpProjection      = "Satellite"
  opt@mpCenterLatF      = 60.
  ; opt@mpLandFillColor = "transparent"
  opt@mpCenterLonF = 0
  opt@mpLimitMode = "LatLon"
  opt@mpMaxLatF = 83
  ; opt@mpMinLatF = 32
  opt@mpMinLatF = 20
  opt@mpMaxLonF = 25
  ; opt@mpMinLonF = -20
  opt@mpMinLonF = -25
  opt@mpGridAndLimbOn = False
  opt@mpGridLineThicknessF = 0.5
  opt@mpPerimOn = True
  opt@mpPerimDrawOrder = "PostDraw"


  ; opt@tmBorderThicknessF = 10
  ; opt@tmXBBorderOn = True
NA = (/10,85,-50,40/)
plot(1) = plot_base(wks,NA,opt)
  opt@gsnLeftString = "MA"
  opt@gsnCenterString = genItem("a",itemType)+"  SST"
  opt@gsnCenterStringFontHeightF = 0.07
  opt@gsnCenterStringOrthogonalPosF = 0.15
plot(2) = plot_base(wks,NA,opt)
  opt@gsnLeftString = "AM"
  delete(opt@gsnCenterString)
plot(3) = plot_base(wks,NA,opt)
  opt@gsnLeftString = "MJ"
plot(4) = plot_base(wks,NA,opt)
  opt@gsnLeftString = "JJ"
plot(5) = plot_base(wks,NA,opt)
  opt@gsnLeftString = "JA"
plot(6) = plot_base(wks,NA,opt)
;# U200
type = "u"
  type@source = "ERA5"
  type@range := (/0,85,0,360/)
  type@level = 200
  type@month = (/7,8/)
opt := True
notDrawAndFrame(opt)
  ; opt@Scale = 10.
  opt@Scale = 0.5
  opt@lbLabelFormat = "%0.1f"
  opt@lbTitlePosition = "Bottom"
  opt@lbTitleDirection = "Across"
  opt@lbOrientation = "Horizontal"
  opt@lbTitleString = "Zonal wind (m s~S~-1~N~)"
  opt@lbTitleAngleF = 0
  opt@lbTitleFontHeightF = 0.02
  opt@lbTitleOffsetF = 0.3
  opt@lbLabelFontHeightF = 0.02
  opt@lbLabelBarOn = False
  opt@pmLabelBarHeightF = 0.06
  opt@pmLabelBarWidthF = 0.6
  opt@pmLabelBarOrthogonalPosF = 0.05
  opt@mode = "hatching"
  opt@hatchingPattern = 6
  opt@hatchingColor = "white"
  opt@hatchingRepeat = 50
  opt@gsnAddCyclic = True
  opt@cnFillColors = (/"#407933","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F0BF2A","#A57E1E"/)
  opt@cnLevels = (/-0.55,-0.45,-0.3,0.3,0.45,0.55/)
  ; opt@cnLinesOn = True
  ; opt@cnLineColor = "White"
  ; opt@cnLineThicknessF = 5
; add_reg(plot(0),ts1,type,range,opt)
add_cor(plot(0),ts1,type,range,opt)
  opt@cnFillOn = False
  opt@cnLinesOn = False
  opt@Scale = 0.2
  opt@mode = "stippling"
  opt@test = True
  opt@sigLevel = 95
  opt@cnFillDotSizeF = 0.004
  opt@cnFillScaleF = 1.4
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
  opt@cnLineThicknessF = 20
  opt@cnLineColors = (/"#0066ff","#0066ff","#0066ff","#0066ff","Firebrick1","Firebrick1","Firebrick1","Firebrick1"/)
  type@range = (/0,65,0,360/)
; add_reg(plot(0),ts1,type,range,opt)
; add_reg(plot(2),ts0,type,range,opt)

;# 加波活动通量
  type@source = "jra55"
  type@range(0) = 27
  type@range(1) = 65
  ; type@range(2) = range(2)-10
  ; type@range(3) = range(3)+10
  ; opt@vcLineArrowColor = "Firebrick1"
  opt@vcLineArrowColor = "Magenta1"
  opt@vcRefAnnoPerimOn = False
  opt@vcRefAnnoString1On = False
  opt@vcRefMagnitudeF = 1.0
  opt@vcRefLengthF = 0.08
  opt@vcRefAnnoParallelPosF = 1.05
  opt@vcRefAnnoString2On = True
  opt@vcRefAnnoString2 = "1 m~S~-2~N~ s~S~-2~N~"
  opt@vcRefAnnoOrthogonalPosF = -0.35
  opt@vcMaxMagnitudeF = 2
  opt@vcMinMagnitudeF = 0.1
  opt@vcLineArrowThicknessF = 10
  opt@vcLineArrowHeadMaxSizeF = 0.05
  opt@vcLineArrowHeadMinSizeF = 0.005
  opt@gsnAddCyclic = True

; add_waf_dev(plot(0),ts1,type,range,opt)
; add_waf_dev(plot(2),ts0,type,range,opt)
;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 7.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
add_topo(plot(0),(/10,50,40,120/),3000,res_topo)
;# fig5B SST
type = "sst"
  type@source = "ersstv5"
  type@level = 700
  delete(opt@cnLineColors)
  delete(opt@cnFillOn)
  delete(opt@cnLinesOn)
  opt@smoothing = True
  opt@Scale = 0.05
  opt@cnFillScaleF = 1.2
  opt@cnFillDotSizeF = 0.0035
  opt@lbLabelFormat = "%0.2f"
  opt@lbTitleString = "Correlation"
  opt@lbTitleFontHeightF = 0.022
  opt@lbLabelFontHeightF = 0.022
  ; opt@pmLabelBarParallelPosF = 0.48
  opt@pmLabelBarWidthF = 0.6
  opt@pmLabelBarHeightF = 0.07
  opt@pmLabelBarOrthogonalPosF = 0.082
  opt@lbLabelBarOn = False
  opt@cnFillDrawOrder = "PreDraw"
  t = t_value(dimsizes(year2)-2)
  opt@cnFillColors = (/"#407933","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F0BF2A","#A57E1E"/)
  ; opt@cnLevels = (/-0.55,-0.45,-t@r90,t@r90,0.45,0.55/)
  opt@cnLevels = (/-0.55,-0.45,-0.3,0.3,0.45,0.55/)
  type@range = (/0,90,0,360/)
  range(0) = 0
; add_reg(plot(0),ts1,type,range,opt)
; add_cor(plot(0),ts1,type,range,opt)
  type@month := (/2,3/)
add_cor(plot(1),ts0,type,range,opt)
  type@month := (/3,4/)
add_cor(plot(2),ts0,type,range,opt)
  type@month := (/4,5/)
add_cor(plot(3),ts0,type,range,opt)
  type@month := (/5,6/)
add_cor(plot(4),ts0,type,range,opt)
  type@month := (/6,7/)
add_cor(plot(5),ts0,type,range,opt)
  type@month := (/7,8/)
add_cor(plot(6),ts0,type,range,opt)
  opt@cnLevels := (/-4,-3,-2,-1,1,2,3,4/)
  opt@cnFillOn = False
  opt@cnLinesOn = False
  opt@Scale = 0.2
  opt@mode = "stippling"
  opt@test = True
  opt@sigLevel = 95
  type@month := (/2,3/)
add_reg(plot(1),ts0,type,range,opt)
  type@month := (/3,4/)
add_reg(plot(2),ts0,type,range,opt)
  type@month := (/4,5/)
add_reg(plot(3),ts0,type,range,opt)
  type@month := (/5,6/)
add_reg(plot(4),ts0,type,range,opt)
  type@month := (/6,7/)
add_reg(plot(5),ts0,type,range,opt)
  type@month := (/7,8/)
add_reg(plot(6),ts0,type,range,opt)

; type = "lwa"
; add_cor(plot(1),ts1,type,range,opt)

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
; add_lc_labels(plot(1),range,rlable)
; add_lc_labels(plot(2),range,rlable)

res_line := True
  res_line@gsLineThicknessF = 2
add_line(plot(0),(/0,180,360/),(/85,85,85/),res_line)
add_line(plot(0),(/0,180,360/),(/25,25,25/),res_line)

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
    line@gsLineThicknessF = 25
    line@gsLineDashPattern = 0
    ; line@gsLineColor = "#eece00"
    ; line@gsLineColor = "DodgerBlue"
    ; line@gsLineColor = "#c872fe"
    line@gsLineColor = "Firebrick1"
    ; line@gsLineColor = "#c76dff"
    line@txJust = "BottomLeft"
    line@txFontColor = "DodgerBlue"
  lat_JA_new := lat_JA({23:123})
  ; lat_JA_new := lat_JA({20:150})
  add_line(plot(0),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(1),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(6),lat_JA_new&lon,lat_JA_new,line)
  ; add_line(plot(7),lat_JA_new&lon,lat_JA_new,line)
box := LRange
  ; box@gsLineColor = "#c872fe"
  box@gsLineColor = "Firebrick1"
  box@gsLineThicknessF = 20
  add_lineBox(plot(1),box)
  add_lineBox(plot(2),box)
  add_lineBox(plot(3),box)
  add_lineBox(plot(4),box)
  add_lineBox(plot(5),box)
  add_lineBox(plot(6),box)
box = RRange
  box@gsLineColor = "#c872fe"
  box@gsLineColor = "DodgerBlue"
  box@gsLineThicknessF = 20
  add_lineBox(plot(0),box)
  ; add_lineBox(plot(2),box)
;# 前两张组图
resp = True
  resp@gsnFrame = False
  resp@gsnPanelLabelBar = True
  resp@gsnPanelScalePlotIndex = 1
  resp@lbOrientation = "Horizontal"
  resp@lbTitleString = "Correlation"
  resp@lbTitlePosition = "Right"
  resp@lbTitleDirection = "Across"
  ; resp@lbTitleAngleF = 90
  resp@pmLabelBarHeightF = 0.044
  resp@pmLabelBarWidthF = 0.7
  resp@pmLabelBarOrthogonalPosF = -0.01
  resp@pmLabelBarParallelPosF = 0.
  resp@lbTitleFontHeightF = 0.014
  resp@lbTitleOffsetF = 0.05
  resp@lbLabelFontHeightF = 0.014
  resp@gsnPanelScaleF = (/0.55,0.25,0.25,0.25,0.25,0.25,0.25/)
  ; resp@gsnPanelYF = (/0.95,0.9/)
  ; resp@gsnPanelXF = (/0.04,0.6/)
  resp@gsnPanelYF = (/0.90,0.89,0.89,0.89,0.685,0.685,0.685/)
  resp@gsnPanelXF = (/0.6,0.03,0.22,0.4,0.03,0.22,0.4/)
  resp@gsnPanelRowSpec = True
  ; resp@gsnPanelYWhiteSpacePercent = 5.
gsn_panel(wks,plot,(/1,3,3/),resp)

;# 时间序列
res_ts := True
notDrawAndFrame(res_ts)
  res_ts@vpHeightF = 0.2
  res_ts@vpWidthF = 1.25
  res_ts@gsnLeftString = genItem("c",itemType)+"  Time series of EMCA1-SST, EMCA1-U200 & Projected ESWJ index"
  res_ts@gsnLeftStringFontHeightF = 0.025
  res_ts@gsnLeftStringParallelPosF = 0.06
  res_ts@gsnLeftStringOrthogonalPosF = 0.0
  ; res_ts@gsnRightString = "R (U200, SST) = "+sprintf("%.2f",escorc(ts0, ts1))+", "+r2pStringDev(escorc(ts0, ts1),dimsizes(ts0))
  ; res_ts@gsnRightStringFontHeightF = 0.025
  res_ts@tmYLLabelFontHeightF = 0.02
  res_ts@tmXBLabelFontHeightF = 0.02
  res_ts@minmax = (/-2.5,2.5/)
  res_ts@gsnXYBarChart = True
  res_ts@gsnXYBarChartColors = (/"#363636"/)
  res_ts@gsnXYBarChartBarWidth = 0.5
  res_ts@xyLineThicknessF = 25
  ; res_ts@tiXAxisString = "Year"
  ; res_ts@tiXAxisFontHeightF = 0.02
  res_ts@tmYLValues = (/-2.5,0,2.5/)
  res_ts@tmYLMode = "Explicit"
  res_ts@trXMaxF = 2042
  res_ts@gsnYRefLineColor = "White"
  res_ts@gsnYRefLineColors = (/"White"/)
  res_ts@tmXBTickSpacingF = 5
  res_ts@tmXBTickStartF = 2000
  res_ts@tmXBMode = "Explicit"
  res_ts@tmXBLabels = (/"2000","2005","2010","2015","2020","Year","","","",""/)
  res_ts@tmXBValues = (/2000,2005,2010,2015,2020,2025,2030,2035,2040,2045/)
  ; res_ts@tiXAxisOffsetYF = 0.01
; plotSVD = plot_ts(wks,ts0,res_ts)
plotSVD = plot_ts(wks,EWJA2,res_ts)
  res_ts@gsnXYBarChart = False
  res_ts@xyLineColor = "Firebrick1"
  res_ts@xyLineThicknessF = 30
add_ts(plotSVD,ts0,res_ts)
  res_ts@xyLineColor = "#007efb"
add_ts(plotSVD,ts1,res_ts)
ts_ref = ts0
ts_ref = 0
res_ts@xyLineColor = "Black"
res_ts@xyLineThicknessF = 3
add_ts(plotSVD,ts_ref,res_ts)
text := "1. EMCA1-U200"
  text@txFontColor = "#007efb"
  text@txFontHeightF = 0.02
  text@txJust = "CenterLeft"
  
textX = 0.57
add_string(plotSVD,text,textX,1.05)
text = "2. EMCA1-SST"
  text@txFontColor = "Firebrick1"
add_string(plotSVD,text,textX,0.75)
text = "3. ESWJ"
  text@txFontColor = "Black"
add_string(plotSVD,text,textX,0.45)

text = "R~B~1,3~N~ = "+sprintf("%.2f",escorc(EWJA2, ts1))+"~F21~, "+r2pStringDev(escorc(EWJA2, ts1),dimsizes(ts0))
  text@txFontColor = "Black"
  text@txJust = "CenterLeft"
  text@txFont = 22
  text@txFontHeightF = 0.02
; add_text(plotSVD,text,2000.7,-2.5)
textX = 0.75
add_string(plotSVD,text,textX,0.78)
; text = r2pStringDev(escorc(EWJA2, ts1),dimsizes(ts0))
;   text@txFont = 21
; add_string(plotSVD,text,textX,0.63)

text = "R~B~2,3~N~ = "+sprintf("%.2f",escorc(EWJA2, ts0))+"~F21~, "+r2pStringDev(escorc(ts0, EWJA2),dimsizes(ts0))
  text@txFontColor = "Black"
  text@txFont = 22
; add_text(plotSVD,text,2000.7,-1.8)
add_string(plotSVD,text,textX,0.48)
; text = r2pStringDev(escorc(ts0, EWJA2),dimsizes(ts0))
;   text@txFont = 21
; add_string(plotSVD,text,textX,0.24)

text = "R~B~1,2~N~ = "+sprintf("%.2f",escorc(ts0, ts1))+"~F21~, "+r2pStringDev(escorc(ts0, ts1),dimsizes(ts0))
  text@txFont = 22
add_string(plotSVD,text,textX,1.08)
; text = r2pStringDev(escorc(ts0, ts1),dimsizes(ts0))
;   text@txFont = 21
; add_string(plotSVD,text,textX,textX)
; print(R2p(escorc(EWJA2, ts0),dimsizes(EWJA2)))
; print(R2p(escorc(EWJA2, ts1),dimsizes(EWJA2)))
; print(R2p(escorc(ts0, ts1),dimsizes(EWJA2)))
resp := True
  resp@gsnMaximize = False
  resp@gsnPanelScaleF = 0.732
  resp@gsnFrame = False
  resp@gsnPanelYF = 0.4
  resp@gsnPanelXF = 0.055
gsn_panel(wks,plotSVD,(/1,1/),resp)


frame(wks)
delete(wks)
system("gs -q -sDEVICE=png16m -sBATCH -sOutputFile="+fileName+".png -dNOPAUSE -r200 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "+fileName+".pdf")
show(fileName+".png")
end