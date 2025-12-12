load "indices.ncl"
begin

  pdf = "pdf"
    pdf@wkPaperWidthF = 30
    pdf@wkPaperHeightF = 30

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
wks = gsn_open_wks(pdf,fileName)
;# fig2A-D
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
  size@tiYAxisString = (/"~F22~P1~F21~","","~F22~P2~F21~",""/)
  size@tiYAxisFontHeightF = 0.038
  size@tiYAxisAngleF = 0
  ; size@tiYAxisOffsetXF = -0.01
  size@gsnLeftStringFontHeightF = 0.045
  size@gsnLeftStringParallelPosF = 0.31
  size@gsnLeftStringOrthogonalPosF = 0.11
  size@tmXBTickSpacingF = 45
  ; size@mpProjection = "LambertConformal"
  size@mpLambertParallel1F = 20
  size@mpLambertParallel2F = 55
  ; size@gsnMaskLambertConformal = True
  size@mpGridAndLimbOn = False
  size@mpGridLonSpacingF = 30
  size@mpGridLatSpacingF = 15
  size@mpGridLineThicknessF = 0.5
  ; size@mpGridLineDashPattern = 1
  ; size@mpGeophysicalLineColor = "#206e22"
  size@mpGeophysicalLineColor = "Black"
  size@mpGeophysicalLineColor = "#78CFD5"
  size@mpPerimOn         = False 
  ; size@mpPerimDrawOrder = "PostDraw"

  size@mpProjection      = "Satellite"
  size@mpCenterLatF      = 35.
  ; size@mpLandFillColor = "transparent"
  ; size@mpLandFillColor = "#f2f2f2"
  size@mpLandFillColor = "White"
  ; size@mpFillColor = "#f2f2f2"
  ; size@mpFillColors = (/"#f2f2f2"/)
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
notDrawAndFrame(optreg)
  opt@Scale = 0.7
  opt@gsnStringBold = True
  opt@lbLabelBarOn = False
  opt@pmLabelBarWidthF = 0.7

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
  ; opt@cnFillColors = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  opt@cnFillColors = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  opt@cnLevels = (/-0.7,-0.5,-0.3,-0.1,0.1,0.3,0.5,0.7/)
  opt@lbLabelFormat = "%0.1f"
  ; opt@cnFillColors = (/"#0E2245","#223868","#105797","#1B71B6","#2392C9","#28A0CE","#4EC0D9","#98D6E3","#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)
  ; opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.5,-0.4,-0.3,-0.25,0.25,0.3,0.4,0.5,0.6,0.7,0.8,0.9/)
  t = t_value(dimsizes(year01))
  print(t)
  ; opt@cnLevels = (/-0.9,-0.8,-0.7,-0.6,-0.55,-0.5,-0.45,-t@r90,t@r90,0.45,0.5,0.55,0.6,0.7,0.8,0.9/)
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
optreg@test = True
; optreg@hatchingPattern = 8
optreg@cnLineThicknessF = 2.
optreg@smoothing = True
; optreg@cnLineLabelsOn = True
; optreg@cnLineLabelInterval = 1
; ; optreg@cnLineLabelBackgroundColor = "transparent"
; optreg@cnLineLabelFontColor = "#206e22"
; optreg@cnLineLabelFont = 22
; optreg@cnLineLabelFontHeightF = 0.02

;# 青藏高原
res_topo := True
  res_topo@mode = "contour"
  res_topo@cnLineColor = "#575757"
  res_topo@cnLineThicknessF = 5.
  res_topo@cnFillOpacityF = 0.7
  res_topo@cnFillColor = "#575757"
  ; res_topo@cnLineDrawOrder = "PreDraw"
ranges(2) = 40
add_topo(plot(0),ranges,3000,res_topo)
add_topo(plot(1),ranges,3000,res_topo)
add_topo(plot(2),ranges,3000,res_topo)
add_topo(plot(3),ranges,3000,res_topo)


optreg@cnLinesOn = False
optreg@FDR = False
optreg@mode = "contour"
optreg@sigLevel = 95
optreg@cnFillScaleF := 1.5
; optreg@stipplingColor = "#b8b8b8"
; optreg@stipplingColor = "#cdcdcd"
; optreg@stipplingColor = "#0e5670"
optreg@stipplingColor = "Grey"
optreg@cnFillDotSizeF = 0.0045
optreg@cnLineColor = "Black"
optreg@cnLineThicknessF = 5
notDrawAndFrame(optreg)
add_reg(plot(0),EOF1_p01,type,ranges,optreg)
add_reg(plot(1),EOF2_p01,type,ranges,optreg)
add_reg(plot(2),EOF1_p2,type,ranges,optreg)
add_reg(plot(3),EOF2_p2,type,ranges,optreg)


optreg@cnLinesOn = False
optreg@FDRRange = rangeEOF
optreg@FDR = True
; optreg@mode = "hatching"
optreg@mode = "stippling"
optreg@sigLevel = 90
optreg@hatchingRepeat = 3
optreg@Scale = 1.1
optreg@cnFillScaleF := 1.5
; optreg@cnFillScaleF = 1.125
; optreg@hatchingColor = "#cdcdcd"
; optreg@hatchingColor = "#f8f8f8"
optreg@hatchingColor = "White"
optreg@stipplingColor = "White"
; optreg@stipplingColor = "Grey43"
optreg@cnFillDotSizeF = 0.0045
add_reg(plot(0),EOF1_p01,type,ranges,optreg)
add_reg(plot(1),EOF2_p01,type,ranges,optreg)
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
; line := ""
;     line@txFontHeightF = 0.04
;     line@txFont = 22
;     line@txJust = "CenterLeft"
;     line@txOffsetXF = 4
;     line@txOffsetYF = -1
;     ; line@txLineHeightF = 1.
;     ; line@gsLineDashPattern = 1
;     line@txJust = "BottomLeft"
;     line@txOffsetYF = -25
;     line@txOffsetXF = -145
;     line@txOffsetXF = -145
;     line@txOffsetYF = -10
;     line@gsLineThicknessF = 15
;     line@gsLineDashPattern = 0
;     line@gsLineColor = "Firebrick1"
;     ; line@gsLineColor = "#c872fe"
;     ; line@gsLineColor = "#eece00"
;     line@txJust = "BottomLeft"
;     line@txFontColor = "#0000ff"
;   lat_JA_new = lat_JA({23:123})
;   add_line(plot(0),lat_JA_new&lon,lat_JA_new,line)
;   add_line(plot(1),lat_JA_new&lon,lat_JA_new,line)
;   add_line(plot(2),lat_JA_new&lon,lat_JA_new,line)
;   add_line(plot(3),lat_JA_new&lon,lat_JA_new,line)

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
    line@gsLineThicknessF = 25
    line@gsLineDashPattern = 0
    line@gsLineColor = "#0082df"
    line@txJust = "BottomLeft"
    line@txFontColor = "#0082df"
  lat_JA_WAJ_P1 = lat_JA01({rangeWAJ(2):rangeWAJ(3)})
  lat_JA_WAJ_P2 = lat_JA2({rangeWAJ(2):rangeWAJ(3)})
  lat_JA_EAJ_P1 = lat_JA01({rangeEAJ(2):rangeEAJ(3)})
  lat_JA_EAJ_P2 = lat_JA2({rangeEAJ(2):rangeEAJ(3)})
  lat_JA_Center_P1 = lat_JA01({rangeWAJ(3):rangeEAJ(2)})
  lat_JA_Center_P2 = lat_JA2({rangeWAJ(3):rangeEAJ(2)})
  add_line(plot(0),lat_JA_WAJ_P1&lon,lat_JA_WAJ_P1,line)
  add_line(plot(1),lat_JA_WAJ_P1&lon,lat_JA_WAJ_P1,line)
  add_line(plot(2),lat_JA_WAJ_P2&lon,lat_JA_WAJ_P2,line)
  add_line(plot(3),lat_JA_WAJ_P2&lon,lat_JA_WAJ_P2,line)
    line@gsLineColor = "red"
    line@txFontColor = "red"
  add_line(plot(0),lat_JA_EAJ_P1&lon,lat_JA_EAJ_P1,line)
  add_line(plot(1),lat_JA_EAJ_P1&lon,lat_JA_EAJ_P1,line)
  add_line(plot(2),lat_JA_EAJ_P2&lon,lat_JA_EAJ_P2,line)
  add_line(plot(3),lat_JA_EAJ_P2&lon,lat_JA_EAJ_P2,line)


box := rangeEOF
  box@gsLineThicknessF = 5
  ; box@gsLineColor = "Magenta"
  ; box@gsLineColor = "Firebrick1"
  box@gsLineColor = "DodgerBlue"
  ; box@gsLineDashPattern = 1
  box@gsLineDashPattern = 0
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



;# 前四张组图
resp := True
  ; resp@gsnPanelMainString = "U200 EOF1"
  resp@gsnPanelLabelBar = True
  resp@lbLabelFontHeightF = 0.015
  resp@lbLabelStride = 1
  ; resp@lbLabelStride = 3
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
  ; opt@gsnLeftString = genItem("e",itemType)+"  UDZC Index"
  opt@gsnLeftString = genItem("e",itemType)+"  PC1"
  opt@gsnLeftStringFontHeightF = 0.025
  opt@gsnLeftStringOrthogonalPosF = 0.04
  opt@gsnLeftStringParallelPosF = -0.03
  opt@gsnCenterString = "WJA index"
  opt@gsnCenterStringFontColor = "DodgerBlue"
  opt@gsnCenterStringFontHeightF = 0.025
  opt@gsnCenterStringParallelPosF = 0.78
  opt@gsnCenterStringOrthogonalPosF = 0.04
  opt@gsnRightString = "EJA index"
  opt@gsnRightStringFontColor = "firebrick1"
  opt@gsnRightStringFontHeightF = 0.025
  opt@gsnRightStringOrthogonalPosF = 0.04
  opt@tiXAxisString = "Year"
  opt@tiXAxisFontHeightF = 0.02
  opt@tiYAxisString = "std. dev."
  opt@tiYAxisFontHeightF = 0.02
  opt@tiYAxisOffsetXF = 0.005
  opt@tmXBTickSpacingF = 10
  opt@tmXBTickStartF = 1960
  opt@vpHeightF = 0.3
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
  opt@minmax = (/-3,3.4/)
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
  ; opt@gsnXYBarChartColors = "Grey"
  opt@gsnXYBarChartFillOpacityF = 0.8

  ; opt@tmYRLabelFontHeightF = 0.01
  ; opt@tmYRLabelFontColor = "tomato"
; plot(0) = gsn_csm_xy(wks, Jet_ERA5&year, Jet_ERA5, opt)
; print(combined_index)
; combined_index = (/dtrend_leftdim(combined_index, True)/)
ts := EWJA
; ts({year01}) = (/designal(ts({year01}),EAJ01(0,:))/)
; ts = (/dtrend_leftdim(ts, True)/)
; print(escorc(ts({year01}), EAJ01(0,:)))
ts({year01}) = (/EOF1_p01/)
ts({year2}) = (/EOF1_p2/)



; exit()
; ts := combined_index
; opt@gsnXYBarChart = False
; opt@xyLineColor = "Black"
barColorP1 = "Grey"
barColorP2 = "Black"
; opt@gsnXYBarChartColors := (/barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2/)
; opt@gsnXYBarChartColors2 = (/barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP1,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2,barColorP2/)
  opt@gsnXYBarChartColors = "Black"
plotEAWJ = plot_ts(wks,ts,opt)
;   opt@gsnXYBarChart = True
; add_ts(plotEAWJ,EOF1_p2,opt)
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
  opt@gsnLeftString = "UDZC"
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
  res = True
  res@xyLineColor = "DodgerBlue"
  res@xyMarkLineMode = "MarkLines"
  res@xyMarkerSizeF = 0.012
  res@xyLineThicknessF = 5
  WAJ_index = dim_standardize_Wrap(WAJ_index, 0)
add_ts(plotEAWJ,WAJ_index,res)
  res@xyLineColor = "transparent"
  res@xyMarkerSizeF = 0.010
  res@xyMarkerColors = "White"
add_ts(plotEAWJ,WAJ_index,res)
  res@xyLineThicknessF = 8
  res@xyMarkLineMode = "Lines"
  res@xyLineColor = "firebrick1"
  EAJ_index = dim_standardize_Wrap(EAJ_index, 0)
add_ts(plotEAWJ,EAJ_index,res)

opt@xyLineColor = "DimGray"
opt@xyLineThicknessF = 5
opt@xyMarkLineMode = "Lines"
; add_ts(plotEAWJ,EOF1_p01,opt)
; add_ts(plotEAWJ,EOF1_p2,opt)
opt@xyLineColor = "DimGray"
opt@xyDashPattern = 13
; add_ts(plotEAWJ,EOF2_p01,opt)
; add_ts(plotEAWJ,EOF2_p2,opt)

opt@xyMarkLineMode = "MarkLines"
opt@xyMarker = 4
opt@xyMarkerSizeF = 0.014
; opt@xyMarkerThicknessF
; add_ts(plotEAWJ,ts2,opt)
ts_tem := dim_standardize_Wrap(ESWJ({year01}), 0)
df = dimsizes(EWJA2)-2
R_UDZC_WJA = escorc(EWJA2,WAJ_index2)
R_UDZC_EJA = escorc(EWJA2,EAJ_index2)
text := "R (UDZC, WJA) = "+sprintf("%0.2f", R_UDZC_WJA)+", ~F21~"+r2pStringDev(R_UDZC_WJA,df)
; text := "R = "+sprintf("%0.2f", escorc(ts0, ESWJ0))+", p<0.01"
  text@txFontHeightF = 0.02
  text@txFontColor = "DodgerBlue"
  text@txFont = 22
; add_text(plotEAWJ,text,2011,-2.9)
; add_text(plotEAWJ,text,1965,-6.)

text = "R (UDZC, EJA) = "+sprintf("%0.2f", R_UDZC_EJA)+", ~F21~"+r2pStringDev(R_UDZC_EJA,df)
; text = "R = "+sprintf("%0.2f", escorc(ts2, ESWJ2))+", p<0.01"
  text@txFontColor = "firebrick1"
; add_text(plotEAWJ,text,2011,2.9)

text = "PC1"
  text@txFontColor = "DimGray"
  text@txJust = "CenterLeft"
; add_text(plotEAWJ,text,1962,-2.5)
text = "PC2"
; add_text(plotEAWJ,text,1970,-2.5)

resLine := True
  resLine@gsLineThicknessF = 5
  resLine@gsLineColor = "DimGray"
; add_line(plotEAWJ,(/1958,1961/),(/-2.5,-2.5/),resLine)
  resLine@gsLineDashPattern = 13
; add_line(plotEAWJ,(/1966,1969/),(/-2.5,-2.5/),resLine)
text := "WJA"
  text@txFontColor = "#0082df"
  text@txJust = "CenterLeft"
  text@txFontHeightF = 0.022
textY = 1.215
; add_string(plotEAWJ,text,0.81,textY)

text = "EJA"
  text@txFontColor = "red"
; add_string(plotEAWJ,text,0.892,textY)

resp := True
  resp@gsnFrame = False
  resp@gsnPanelXF = 0.08
  resp@gsnPanelYF = 0.35
  resp@gsnPanelBottom = 0.05
  resp@gsnPanelTop = 0.292
  resp@gsnMaximize = True
  resp@gsnPanelScaleF = 0.7
gsn_panel(wks,plotEAWJ,(/1,1/),resp)

ts := EWJA
cor_UDZC_PC1_P1 = escorc(ts({year01}), EOF1_p01)
cor_UDZC_PC2_P1 = escorc(ts({year01}), EOF2_p01)
cor_WJA_PC1_P1 = escorc(WAJ_index01, EOF1_p01)
cor_WJA_PC2_P1 = escorc(WAJ_index01, EOF2_p01)
cor_EJA_PC1_P1 = escorc(EAJ_index01, EOF1_p01)
cor_EJA_PC2_P1 = escorc(EAJ_index01, EOF2_p01)

cor_UDZC_PC1_P2 = escorc(EWJA2, EOF1_p2)
cor_UDZC_PC2_P2 = escorc(EWJA2, EOF2_p2)
cor_WJA_PC1_P2 = escorc(WAJ_index2, EOF1_p2)
cor_WJA_PC2_P2 = escorc(WAJ_index2, EOF2_p2)
cor_EJA_PC1_P2 = escorc(EAJ_index2, EOF1_p2)
cor_EJA_PC2_P2 = escorc(EAJ_index2, EOF2_p2)
;# 热力图
data := (/\
  (/cor_UDZC_PC1_P1,cor_UDZC_PC2_P1/),\
  (/cor_WJA_PC1_P1,cor_WJA_PC2_P1/),\
  (/cor_EJA_PC1_P1,cor_EJA_PC2_P1/),\
  (/cor_UDZC_PC1_P2,cor_UDZC_PC2_P2/),\
  (/cor_WJA_PC1_P2,cor_WJA_PC2_P2/),\
  (/cor_EJA_PC1_P2,cor_EJA_PC2_P2/)\
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
  opt@vpXF = 0.785
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
  opt@tiYAxisString = "~V-15F22~P1~C~~C~~C~~C~~C~~C~~C~~C~~C~~C~~C~P2~F21~"
  opt@tiYAxisFontHeightF = 0.014
  opt@tiYAxisAngleF = -90
  opt@tiYAxisOffsetXF = 0.281
  opt@tiYAxisAngleF = 0
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
gsn_polygon_ndc(wks, (/0.5,0.5,0.508,0.508/)+0.463, (/0.725,0.9505,0.9505,0.725/), res_line)
  res_line@gsFillColor = "#4D4D4D"
gsn_polygon_ndc(wks, (/0.5,0.5,0.508,0.508/)+0.463, (/0.7255,0.951,0.951,0.7255/)-0.226, res_line)

; gsn_polyline_ndc(wks, (/0.5,0.5/), (/0.7,0.9/), resLine)
; pgres := (/-10,10,1998.5,2023/)
;   pgres@gsFillOpacityF = 0.1
;   pgres@gsFillColor = "#58BFD8"
; add_fillBox(plot_ESWJ,pgres)
; draw(plot_ESWJ)
; frame(wks)
delete(wks)
system("gs -q -sDEVICE=png16m -sBATCH -sOutputFile="+fileName+".png -dNOPAUSE -r200 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "+fileName+".pdf")
show(fileName+".png")
; frame(wks)
; show(fileName+".png")
end