;***********************************************************************;
; Function : gsn_open_wks                                               ;
;               type : type of workstation to open                      ;
;               name : name of workstation                              ;
;                                                                       ;
; This function opens either an X11 window, an NCGM file, a Postscript  ;
; or a PDF file depending on "type", which can be "x11", "ncgm", "ps"   ;
; or "pdf". If "type" is a PS or PDF file or an NCGM, then it will be   ;
; named <name>.ps or <name>.pdf <name>.ncgm respectively. This function ;
; also looks for a resource file called "name.res". If it exists, then  ;
; it loads the resources defined in that file. This function returns    ;
; the workstation id.                                                   ;
;***********************************************************************;
undef("gsn_open_wks")
function gsn_open_wks(type[1]:string,name[1]:string)
local i, wks, appusrdir, name_char, not_found, res_file, res_dir, type2, realtype, suffix
begin
    type2   = type          ; Make copy of type and its resources
    type2  = str_lower(type)
    res_dir = "./"          ; Default resource directory.
    res_file = "gsnapp"     ; Default resource file name.
    valid_type = False      ; Is type valid?

;
; Parse "name" to get the directory and the file prefix.
;
    if(name.ne."") then
      name_char = stringtocharacter(name)
      name_len  = dimsizes(name_char)-1
      i = name_len-1      ; Start checking if a directory pathname
      not_found = True    ; was specified for the resource file.
      do while(not_found.and.i.ge.0)
        if(name_char(i).eq."/")
          res_dir  = charactertostring(name_char(0:i))
          not_found = False
        end if
        i = i - 1
      end do

      res_file = charactertostring(name_char(i+1:name_len-1))

      if(isatt(name,"appUsrDir").and.not_found)
        res_dir = name@appUsrDir   ; No directory specified.
      end if
    end if

    ; This 5-line block addresses Jira 1750; we test to make sure the target directory
    ; exists and is writable.
    cmdStr = "if [ -w " + res_dir + " ] ; then echo 1 ; else echo 0 ; fi"
    if (type.ne."x11" .and. systemfunc(cmdStr).ne.1) then
        print("gsn_open_wks: Error: directory '" + res_dir + "' does not exist or lacks write permissions.");
        ; 这里直接退出对NCL Notebook不友好，改成return
        return
        ; status_exit(1)
    end if

    appid = create res_file appClass defaultapp
        "appDefaultParent" : True
        "appUsrDir"        : res_dir
    end create

;
; If we had a case statement or an "elseif" in NCL, this next
; section would look better!
;
    wks = new(1,graphic,"No_FillValue")

    if (type2.eq."x11") then
      wks = gsn_open_x11(res_file, type2)
      valid_type = True
    end if

    if (type2.eq."oldps".or.type2.eq."oldeps".or. \
        type2.eq."epsi".or.(type2.eq."ps".and..not.ismissing(getenv("NCARG_OLD_PS"))).or. \
        (type2.eq."eps".and..not.ismissing(getenv("NCARG_OLD_EPS")))) then
      realtype = type2   ; copy value and attributes
      suffix = type2
      if (realtype.eq."oldps") then
        realtype = "ps"
        suffix = "ps"
      end if
      if (realtype.eq."oldeps") then
        realtype = "eps"
        suffix = "eps"
      end if
      ps_file = get_res_value(realtype,"wkPSFileName",res_file + "." + suffix)
      ps_file@res_file = res_file
      wks = gsn_open_ps(realtype,res_dir+ps_file)
      valid_type = True
    end if

    if (type2.eq."ncgm") then
      ncgm_file = get_res_value(type2,"wkMetaName",res_file + ".ncgm")
      ncgm_file = res_dir + ncgm_file
      ncgm_file@res_file = res_file
      if (isatt(type2,"wkColorMap"))
        ncgm_file@wkColorMap = type2@wkColorMap
      end if
      wks = gsn_open_ncgm(ncgm_file)
      valid_type = True
    end if

    if (type2.eq."oldpdf".or.(type2.eq."pdf".and..not.ismissing(getenv("NCARG_OLD_PDF")))) then
      realtype = type2  ; copy value and attributes
      if (realtype.eq."oldpdf") then
          realtype = "pdf"
      end if
      pdf_file = get_res_value(realtype,"wkPDFFileName", \
                               res_file + "." + "pdf")
      pdf_file@res_file = res_file
      wks = gsn_open_pdf(realtype, res_dir+pdf_file)
      valid_type = True
    end if
    ; 大部分的图片都是属于cairo这里的
    if (is_cairo_wks(type2)) then
      cairo_file = get_res_value(type2,"wkFileName", res_file)
      if (is_cairo_png(type2)) then
        cairo_file = get_res_value(type2,"wkImageFileName", cairo_file)
      end if
      cairo_file@res_file = res_file
      wks = gsn_open_cairo(type2, res_dir+cairo_file)
      valid_type = True
    end if

    if (type2.eq."xwd") then
      image_file = get_res_value(type2,"wkFileName", res_file)
      image_file@res_file = res_file
      wks = gsn_open_image(type2, res_dir+image_file)
      valid_type = True
    end if

    if (.not.valid_type.or.ismissing(wks)) then
      print("Error: gsn_open_wks: '"+ type2 + "' is an invalid workstation type.")
      exit
    end if

;
; Apply other resources.
;
; First create list of resources that we *don't* want applied, as we've
; should have applied them by this point.
;
  varatts = getvaratts(type2)
  if(.not.any(ismissing(varatts))) then
    wks_res = True
    res_list = (/"wkColorMap","wkWidth","wkHeight","wkColorModel", \
                 "wkPSResolution","wkPDFResolution","wkVisualType", \
                 "wkPaperSize","wkPaperWidthF","wkPaperHeightF", \
                 "_FillValue"/)
    do i=0,dimsizes(varatts)-1
      if(all(varatts(i).ne.res_list)) then
        wks_res@$varatts(i)$ = type2@$varatts(i)$
      end if  
    end do
    attsetvalues_check(wks,wks_res)
    delete(wks_res)
  end if
  delete(varatts)
;
; Return workstation and application id.
;
    wks@name = res_file
    wks@app  = appid 
    wks@path = name+"."+type
    return(wks)
end

undef("open_tem_wks")
function open_tem_wks(res)
local tem_wks,type
begin
  type = "png"
  if(isatt(res, "type"))then
    type = res@type
  end if
  type@wkHeight = 2000
  type@wkWidth = 2000
  copy_VarAtts(res, type)
  tem_wks = gsn_open_wks(type, ".tem")
  return tem_wks
end

undef("fill_xy_ref_curves")
procedure fill_xy_ref_curves (wks,xyobj,reftype,xin,yin,ncurves,nref,\
                             npts_array,ref_line_array,\
                             ref_greater_fill_colors,\
                             ref_less_fill_colors)
  local xyres_tmp, i, fill_greater, fill_less, var_string
  begin
  ;
  ; Make sure polygons get filled before xy plot is drawn. This way,
  ; any lines will be drawn *after* the fill. This makes the filled 
  ; polygons look better if the l∑ines are drawn thicker.
  ;
    xyres_tmp = True
    ; xyres_tmp@tfPolyDrawOrder = "Predraw"
    xyres_tmp@tfPolyDrawOrder = "Postdraw"
    attsetvalues_check(xyobj,xyres_tmp)

    fill_greater = ref_greater_fill_colors(0,:)
    fill_less    = ref_less_fill_colors(0,:)
    do i=0,max((/ncurves,nref/))-1
      if(dimsizes(ref_greater_fill_colors(:,0)).gt.1)
        fill_greater = ref_greater_fill_colors(i,:)
      end if
      if(dimsizes(ref_less_fill_colors(:,0)).gt.1)
        fill_less = ref_less_fill_colors(i,:)
      end if
      var_string = unique_string("polygons"+i)
      xyobj@$var_string$=fill_xy_ref(wks,xyobj,reftype, \
                                     xin(i,0:npts_array(i)-1), \
                                     yin(i,0:npts_array(i)-1),\
                                     ref_line_array(i),fill_greater,\
                                     fill_less)
    end do
end

undef("fill_xy_ref_curves_dev")
procedure fill_xy_ref_curves_dev (wks,xyobj,reftype,xin,yin,ncurves,nref,\
                             npts_array,ref_line_array,\
                             ref_greater_fill_colors,\
                             ref_less_fill_colors)
  local xyres_tmp, i, fill_greater, fill_less, var_string
  begin
  ;
  ; Make sure polygons get filled before xy plot is drawn. This way,
  ; any lines will be drawn *after* the fill. This makes the filled 
  ; polygons look better if the l∑ines are drawn thicker.
  ;
    xyres_tmp = True
    ; xyres_tmp@tfPolyDrawOrder = "Predraw"
    xyres_tmp@tfPolyDrawOrder = "Postdraw"
    attsetvalues_check(xyobj,xyres_tmp)

    fill_greater = ref_greater_fill_colors(0,:)
    fill_less    = ref_less_fill_colors(0,:)
    do i=0,max((/ncurves,nref/))-1
      if(dimsizes(ref_greater_fill_colors(:,0)).gt.1)
        fill_greater = ref_greater_fill_colors(i,:)
      end if
      if(dimsizes(ref_less_fill_colors(:,0)).gt.1)
        fill_less = ref_less_fill_colors(i,:)
      end if
      var_string = unique_string("polygons"+i)
      xyobj@$var_string$=fill_xy_ref(wks,xyobj,reftype, \
                                     xin(i,0:npts_array(i)-1), \
                                     yin(i,0:npts_array(i)-1),\
                                     ref_line_array(i),fill_greater,\
                                     fill_less)
    end do
end

undef("gsn_csm_xy_dev")
function gsn_csm_xy_dev (wks:graphic,x:numeric,y:numeric,resources:logical)
  local res, xy_object, res2, xfontf, yfontf, font_height, calldraw,  nlines, \
  callframe, left_string, center_string, right_string, main_zone,   ncurves, \
  xinterp, yinterp, bar_chart
  begin
  ; Initialize.
    main_zone     = 2         ; Zone for main title (may change   later)
  ; Whether to fill curves around a reference line
    yref_fill_on       = False
    yref_above_fill_on = False
    yref_below_fill_on = False
    bar_chart     = False     ; Whether we want bars or curves
    res2          = get_resources(resources)
  ;
  ; Write data and plot resource information to a file so we can 
  ; reconstruct plot if desired, without all the computational
  ; code beforehand.
  ;
    if(isatt(res2,"gsnDebugWriteFileName")) then
      gsnp_write_debug_info(x,y,new(1,float),"gsn_csm_xy",res2,2)
    end if
    left_string   = False
    center_string = False
    right_string  = False
    tm_scale      = get_res_value_keep(res2,"gsnScale",True)
    point_outward = get_res_value(res2,"gsnTickMarksPointOutward",  True)
  ; Calculate number of Y points.

    ndimsy = dimsizes(dimsizes(y))
    ndimsx = dimsizes(dimsizes(x))
    if(ndimsx.ne.1.and.ndimsy.ne.1.and.ndimsx.ne.2.and.ndimsy.ne.2)
      print("gsn_csm_xy: Fatal: X and Y must have the same  dimensions sizes, or one must be one-dimensional and both  have the same rightmost dimension.")
      exit
    end if
    if(ndimsx.eq.1)
      nptsx    = dimsizes(x)
      ncurvesx = 1
    else
      nptsx    = dimsizes(x(0,:))
      ncurvesx = dimsizes(x(:,0))
    end if
    if(ndimsy.eq.1)
      nptsy    = dimsizes(y)
      ncurvesy = 1
    else
      nptsy    = dimsizes(y(0,:))
      ncurvesy = dimsizes(y(:,0))
    end if
  ;
  ; Test dimensions. They must both either be the same, or have the
  ; same rightmost dimension.
  ;
    if((ndimsx .gt. 1 .and. ndimsy .gt. 1 .and.(ndimsx.ne.ndimsy.or. .not.all(dimsizes(x).eq.dimsizes(y)))) .or. ((ndimsx.eq.1.or.ndimsy.eq.1).and.nptsx.ne.nptsy))
      print("gsn_csm_xy: Fatal: X and Y must have the same  dimensions sizes, or one must be one-dimensional and both  have the same rightmost dimension.")
      exit
    end if

  ; This section tests for more special resources: those that start
  ; with "gsn."

    if((res2).and..not.any(ismissing(getvaratts(res2))))
      ;
      ; Check if gsnShape set.
      ;
      if(isatt(res2,"gsnShape").and.res2@gsnShape)
        main_zone = main_zone+1 ; Zone for main title
      end if

  ;---Check if gsnYRefLine set.
      yref_line_list = get_ref_line_options(wks,x,y,"y",ncurvesy, res2)
      yref_line = yref_line_list[0]
      yref_line_on = yref_line_list[1]
      yref_line_color = yref_line_list[2]
      yref_line_pattern = yref_line_list[3]
      yref_line_thickness = yref_line_list[4]
      yref_above_fill_on = yref_line_list[5]
      yref_below_fill_on = yref_line_list[6]
      yref_above_fill_color = yref_line_list[7]
      yref_below_fill_color = yref_line_list[8]
      nyref = dimsizes(yref_line)
      yref_fill_on = yref_above_fill_on.or.yref_below_fill_on
      delete(yref_line_list)

  ;---Check if gsnXRefLine set.
      xref_line_list = get_ref_line_options(wks,x,y,"x",ncurvesx, res2)
      xref_line = xref_line_list[0]
      xref_line_on = xref_line_list[1]
      xref_line_color = xref_line_list[2]
      xref_line_pattern = xref_line_list[3]
      xref_line_thickness = xref_line_list[4]
      xref_right_fill_on = xref_line_list[5]
      xref_left_fill_on = xref_line_list[6]
      xref_right_fill_color = xref_line_list[7]
      xref_left_fill_color = xref_line_list[8]
      nxref = dimsizes(xref_line)
      xref_fill_on = xref_right_fill_on.or.xref_left_fill_on
      delete(xref_line_list)

  ; Check for existence of the left, center, and right subtitles.

      check_for_subtitles(res2,left_string,center_string, right_string)
      if(left_string.or.center_string.or.right_string)
        main_zone   = main_zone+1
      end if
    end if                  ; Done checking special resources.

    res2          = True
    res2@gsnDraw  = False     ; Internally, don't draw plot or  advance
    res2@gsnFrame = False     ; frame since we take care of that  later.
    res2@gsnScale = tm_scale  ; Force labels and ticks to be same.

  ; If user explicitly sets X or Y tick marks, then don't label the   X 
  ; or Y axis automatically.

    if(check_attr_enum_value(res2,"tmXBMode","Explicit"))
      set_attr(res2,"tiXAxisString","")
    end if

    if(check_attr_enum_value(res2,"tmYLMode","Explicit"))
      set_attr(res2,"tiYAxisString","")
    end if
  ;
    if(.not.bar_chart.and.yref_fill_on) then
      interp_list = ref_line_interp(x,y,yref_line,"y")
      xinterp  = interp_list[0]
      yinterp  = interp_list[1]
      new_yref_line = interp_list[2]
      new_npts = interp_list[3]
      delete(interp_list)
    end if
  ;
  ; If user sets lgLabelFontHeightF, then lgAutoManage needs to
  ; be False in order for this resource to have any affect.
  ;
    if(isatt(res2,"lgLabelFontHeightF"))
      set_attr(res2,"lgAutoManage",False)
    end if

  ;---Create XY plot
    xyres = get_res_ne(res2,(/"tx","gsnXY","gsnYRef","gsnXRef","gsnAbove","gsnBelow","gsnRight", "gsnLeft"/))

    xy_object = gsn_xy(wks,xinterp,yinterp,xyres)
  ;---Add lat/lon labels to X/Y axes if appropriate units exist.
    add_latlon_labels_xy_plot(xy_object,x,y,res2)

  ;---Fill above/below/left/right Y/X reference line. 
    if(yref_fill_on.and..not.bar_chart) then
        fill_xy_ref_curves_dev(wks,xy_object,"y",xinterp,yinterp, ncurvesy,nyref,new_npts,new_yref_line, yref_above_fill_color, yref_below_fill_color)
    end if

  ; Get title label sizes and tickmark lengths.
    getvalues xy_object
      "vpWidthF"             : width
      "vpHeightF"            : height
      "tiXAxisFontHeightF"   : xfontf
      "tiYAxisFontHeightF"   : yfontf
      "tmYLMajorLengthF"     : ylength
      "tmXBMajorLengthF"     : xlength
      "tmYLMinorLengthF"     : ymlength
      "tmXBMinorLengthF"     : xmlength
    end getvalues

    font_height = min((/xfontf,yfontf/))  ; Make label sizes a  function of the size of the X/Y axis labels.
    major_length = min((/ylength,xlength/))
    minor_length = min((/ymlength,xmlength/))

  ; If the plot is close to square in size, then make the 
  ; three top titles and the tick marks smaller.

    ratio = height/width
    if(ratio.gt.1) 
      ratio = 1./ratio
    end if
    if(ratio.gt.0.5)
      font_height = 0.75 * font_height
      major_length = 0.75 * major_length
      minor_length = 0.75 * minor_length
    end if

  ; Make tick marks same length and point outward.

    tmres = get_res_eq(res2,"tm")
    gsnp_point_tickmarks_outward(xy_object,tmres,xlength,ylength, xmlength, ymlength,major_length, minor_length, point_outward)

  ; Set up three subtitles at top, if they exist.
    subres = get_res_eq(res2,(/"tx","am"/))  ; Get textitem   resources
    subres               = True
    set_attr(subres,"txFontHeightF",font_height)
    add_subtitles(wks,xy_object,left_string,center_string,  right_string, subres)
  return(xy_object)
end

undef("add_text")
procedure add_text (plotid,name,x,y)
local plots,dim,tem_wks,res,option,LH,p,i,str
begin
  plots = dimsizes(plotid)
  dim = dimsizes(name)
  tem_wks = NhlGetParentWorkstation(plotid(0))
  res = True

  exclude := (/"txLineHeightF","txOffsetXF","txOffsetYF"/)
  copy_VarAtts_match(name,res,res_plot,exclude)

  option = True
    option@txOffsetXF = 0
    option@txOffsetYF = 0
    option@txLegend = True
    option@txLineHeightF = 0.1
  copy_VarAtts_match(name,option,"tx","")
  
  ; res@gsMarkerIndex = y0@xyMarkers
  ; res@gsMarkerColor = y0@xyMarkerColor
  ; res@gsMarkerSizeF = get_res_value_keep(y0,"xyMarkerSizeF",res@xyMarkerSizeF)
  LH = option@txLineHeightF
  do p = 0, plots-1
    do i = 0, dim-1
      str = unique_string("text")
      ; res@txFontColor = y0@xyMarkerColor
      plotid@$str$ = gsn_add_text(tem_wks,plotid(p),name(i),x, y-LH*i, res)
    end do
  end do
end

undef("_addString") ; 内部函数
procedure _addString (plotid,text:string,x,y)
  begin
  tmp_wks = NhlGetParentWorkstation(plotid)
  String = create "String" textItemClass tmp_wks
    "txString"      : text
    "txFontHeightF" : get_res_value_keep(text, "txFontHeightF",0.035)
    "txFontColor"   : get_res_value_keep(text, "txFontColor","black")
    "txAngleF"      : get_res_value_keep(text, "txAngleF",0.)
    "txFont"        : get_res_value_keep(text, "txFont",21)
  end create

  anno = NhlAddAnnotation(plotid,String)
  setvalues anno
    "amZone"          : 3      ; Just outside plot area
    "amJust"          : get_res_value_keep(text,"txJust","Centercenter")
    "amSide"          : "Bottom" 
    "amParallelPosF"  : x
    "amOrthogonalPosF": -y
    "amResizeNotify"  : True     ; Resize if plot resized.
  end setvalues
end

undef("add_string")
procedure add_string (plotid,name,x,y)
local option,dim,LH,i
begin 
  option = True
    option@txLineHeightF = 0.1
  copy_VarAtts_match(name,option,"tx","")
  dim = dimsizes(name)
  LH = option@txLineHeightF
  do i = 0, dim-1
    _addString(plotid,name(i),x,y-LH*i)
  end do
end

undef("gsn_add_polyline")
function gsn_add_polyline(wks:graphic,plotid:graphic,x[*]:numeric,\
                           y[*]:numeric,resources:logical)
local res2
begin
  res2 = get_resources(resources)
  return(gsn_add_primitive(wks,plotid,x,y,False,"polyline",res2))
end

undef("add_line")
procedure add_line (plotid,x,y,opt)
local tem_wks,res,str,offsetXF,offsetYF,option
begin
  print(opt)
  option = opt
  tem_wks = NhlGetParentWorkstation(plotid)
  res = get_att_eq(opt,"gs")
  if( .not. isatt(res, "gsLineColor"))then
    res@gsLineColor = "Black"
  end if
  res@tfPolyDrawOrder = "PostDraw"
  ; if( (.not. isatt(res, "gsLineDashPattern")) .or. ismissing(res@gsLineDashPattern))then
  ;   res@gsLineDashPattern = 0
  ; end if
  if( .not. checkAtt(res, "gsLineDashPattern"))then
    res@gsLineDashPattern = 0
  end if
  str = unique_string("polyline")
  plotid@$str$ = gsn_add_polyline(tem_wks, plotid, x, y, res)
  if(typeof(opt) .eq. "string")
    offsetXF = get_res_value_keep(opt,"txOffsetXF",0)
    offsetYF = get_res_value_keep(opt,"txOffsetYF",0)
    option@txFontColor = get_res_value_keep(opt,"txFontColor",res@gsLineColor) 
    add_text(plotid,option,last(x)+offsetXF,last(y)+offsetYF)
  end if
end


undef("add_legend")
procedure add_legend (plotid,name,x,y,opt)
  begin
  tem_wks = NhlGetParentWorkstation(plotid)
  res = True
  exclude = ""
  copy_VarAtts_match(opt,res,res_plot,exclude)

  option = True
    option@opOffsetXF = 0
    option@opOffsetYF = 0
    option@opLegend = True
  copy_VarAtts_match(opt,option,"op",exclude)
  
  ; res@gsMarkerIndex = y0@xyMarkers
  ; res@gsMarkerColor = y0@xyMarkerColor
  ; res@gsMarkerSizeF = get_res_value_keep(y0,"xyMarkerSizeF",res@xyMarkerSizeF)
  str = unique_string("legend")
  plotid@$str$ = gsn_add_polymarker(tem_wks, plotid, x, y, res)
  str = unique_string("text")
  ; res@txFontColor = y0@xyMarkerColor
  plotid@$str$ = gsn_add_text(tem_wks,plotid,name,x+option@opOffsetXF, y+option@opOffsetYF, res)
end

undef("add_box")
procedure add_box (plotid,x,y,w,h,opt)
local tem_wks,res,width,height,polyXF,polyYF,str,offsetXF,offsetYF,position
begin 
  tem_wks = NhlGetParentWorkstation(plotid)
  res = True
    res@gsFillColor = "tomato"
    res@bxDrawOrder = "Postdraw"
  copy_VarAtts_match(opt,res,(/"bx","gs"/),"")
  width = w/2.
  height = h/2.
    res@tfPolyDrawOrder = res@bxDrawOrder
  polyXF = (/x-width,x-width,x+width,x+width,x-width/)
  polyYF = (/y-height,y+height,y+height,y-height,y-height/)
  str = unique_string("rectangle")
  plotid@$str$ = gsn_add_polygon(tem_wks,plotid,polyXF,polyYF,res)
  if(typeof(opt) .eq. "string")
    offsetXF = get_res_value_keep(opt,"txOffsetXF",0)
    offsetYF = get_res_value_keep(opt,"txOffsetYF",0)
    position = get_res_value_keep(opt,"bxTextPosition","center")
    if(position .eq. "right")
      opt@txJust = "CenterLeft"
      add_text(plotid,opt,x+width+0.1+offsetXF,y+offsetYF)
    else
      add_text(plotid,opt,x+offsetXF,y+offsetYF)
    end if
  end if
end

undef("add_lineBox")
procedure add_lineBox (plotid,range)
local tem_wks,res,xs,ys,str,i
begin
  tem_wks = NhlGetParentWorkstation(plotid(0))
  res = True
  copy_VarAtts_match(range,res,(/"gs","tf"/),"")
  xs = (/range(2),range(3),range(3),range(2),range(2)/)
  ys = (/range(0),range(0),range(1),range(1),range(0)/)
  do i = 0, dimsizes(plotid)-1
    str = unique_string("lineBox")
    plotid@$str$ = gsn_add_polyline(tem_wks, plotid(i), xs, ys, res) 
    ; plotid@$str$ = gsn_add_polygon(tem_wks, plotid(i), xs, ys, res)
  end do
end

undef("add_fillBox")
procedure add_fillBox (plotid,range)
local tem_wks,res,xs,ys,str,i
begin
  tem_wks = NhlGetParentWorkstation(plotid(0))
  res = True
  copy_VarAtts_match(range,res,"gs","")
  xs = (/range(2),range(3),range(3),range(2),range(2)/)
  ys = (/range(0),range(0),range(1),range(1),range(0)/)
  do i = 0, dimsizes(plotid)-1
    str = unique_string("lineBox")
    plotid@$str$ = gsn_add_polygon(tem_wks, plotid(i), xs, ys, res)
  end do
end

undef("plot_polar")
function plot_polar (wks, range, opt)
local res,plot,corner,resl,str,str1,str2
begin
  res = True
    ; res@gsnDraw = True
    ; res@gsnFrame = True  
    res@tmXTOn = False
    res@tmYROn = False
    ; res@vpHeightF = 0.5
    ; res@vpWidthF = 0.82
    res@vpXF = 0.135
    res@vpYF = 0.9

    res@mpShapeMode        = "FreeAspect"
    res@tmXBMajorLengthF = 0.01
    res@tmXBLabelDeltaF = -0.4
    res@tmYLLabelDeltaF = -0.4
    res@tmYLLabelFontHeightF = 0.03
    res@tmXBLabelFontHeightF = 0.03
    res@tmYLLabelsOn = True
    res@tmXBLabelsOn = True
    res@tiYAxisString = ""
    res@tiXAxisString = ""
    ; res@gsnAddCyclic = True
    res@mpMinLatF           = range(0)
    res@mpMaxLatF           = range(1)
    res@mpCenterLonF        = range(2)/2+range(3)/2
    ; res@mpMinLonF = range(2)
    ; res@mpMaxLonF = range(3)
    res@tmBorderThicknessF = 5
    ;干掉愚蠢的gsnString，后面自己写
    res@gsnLeftString = ""
    res@gsnRightString = ""
    res@gsnLeftStringFontHeightF = 0.035
    res@gsnRightStringFontHeightF = 0.035
    res@tmXBMinorOn = False
    res@tmYLMinorOn = False
    res@mpOutlineOn                 = True
    res@gsnPolar = "NH"
    ; res@FreeAspect = False
    res@mpShapeMode = "FixedAspectFitBB"
  exclude := (/"cn","lb","Scale","preyear","gsnStringBold","tmLabelFontHeightF","vc","gsnCorner","gsLineThicknessF"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF

  ; plot = gsn_csm_map(wks,res)
  plot = gsn_csm_map_polar(wks, res)
  if(isatt(opt,"gsnCornerString") .and. opt@gsnCornerString .ne. "")
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_r es_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if

  if(get_res_value_keep(opt,"dots",False))
    resl = True
    resl@gsLineColor      = get_res_value_keep(opt,"dotsColor","firebrick1")
    resl@gsLineThicknessF = get_res_value_keep(opt,"dotsLineThicknessF",15.0)
    ; resl@tfPolyDrawOrder = "PostDraw"
    ; resl@xyCurveDrawOrder = "PostDraw"
    str = unique_string("polyline")
    plot@$str$            = gsn_add_polyline(wks, plot,opt@dotslon,opt@dotslat,resl)
    if(get_res_value_keep(opt,"dots1",False))
      str1 = unique_string("polyline") 
      plot@$str1$ = gsn_add_polyline(wks, plot,opt@dotslon1,opt@dotslat1,resl)
    end if
    if(get_res_value_keep(opt,"dots2",False))
      str2 = unique_string("polyline") 
      plot@$str2$ = gsn_add_polyline(wks, plot,opt@dotslon2,opt@dotslat2,resl)
    end if
  end if
  ; if(isatt(var, attnames))
  plot@plot = 0
  return plot
end

undef("plot_base")
function plot_base (wks, range, opt)
local plot,res,corner,resl,str,str1,str2
begin
  res = True
    ; res@gsnDraw = True
    ; res@gsnFrame = True  
    res@tmXTOn = False
    res@tmYROn = False
    res@vpHeightF = 0.5
    res@vpWidthF = 0.82
    res@vpXF = 0.135
    res@vpYF = 0.9

    res@mpShapeMode        = "FreeAspect"
    res@tmXBMajorLengthF = 0.01
    res@tmXBLabelDeltaF = -0.4
    res@tmYLLabelDeltaF = -0.4
    res@tmYLLabelFontHeightF = 0.03
    res@tmXBLabelFontHeightF = 0.03
    res@tmYLLabelsOn = True
    res@tmXBLabelsOn = True
    res@tiYAxisString = ""
    res@tiXAxisString = ""
    res@mpMinLatF           = range(0)
    res@mpMaxLatF           = range(1)
    res@mpCenterLonF        = range(2)/2+range(3)/2
    res@mpMinLonF = range(2)
    res@mpMaxLonF = range(3)
    res@tmBorderThicknessF = 5
    ;干掉愚蠢的gsnString，后面自己写
    res@gsnLeftString = ""
    res@gsnRightString = ""
    res@gsnLeftStringFontHeightF = 0.035
    res@gsnLeftStringOrthogonalPosF = 0.05
    res@tmXBMinorOn = False
    res@tmYLMinorOn = False
    res@mpOutlineOn                 = True
  exclude := (/"cn","lb","Scale","preyear","gsnStringBold","tmLabelFontHeightF","vc","gsnCorner","gsLineThicknessF"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF

  plot = gsn_csm_map(wks,res)
  if(isatt(opt,"gsnCornerString") .and. opt@gsnCornerString .ne. "")
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_r es_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if

  if(get_res_value_keep(opt,"dots",False))
    resl = True
    resl@gsLineColor      = get_res_value_keep(opt,"dotsColor","firebrick1")
    resl@gsLineThicknessF = get_res_value_keep(opt,"dotsLineThicknessF",15.0)
    ; resl@tfPolyDrawOrder = "PostDraw"
    ; resl@xyCurveDrawOrder = "PostDraw"
    str = unique_string("polyline")
    plot@$str$            = gsn_add_polyline(wks, plot,opt@dotslon,opt@dotslat,resl)
    if(get_res_value_keep(opt,"dots1",False))
      str1 = unique_string("polyline") 
      plot@$str1$ = gsn_add_polyline(wks, plot,opt@dotslon1,opt@dotslat1,resl)
    end if
    if(get_res_value_keep(opt,"dots2",False))
      str2 = unique_string("polyline") 
      plot@$str2$ = gsn_add_polyline(wks, plot,opt@dotslon2,opt@dotslat2,resl)
    end if
  end if
  ; if(isatt(var, attnames))
  plot@plot = 0
  return plot
end

undef("plot_bases")
function plot_bases (wks, range, opt)
local plotSize,plot,option,res,i,a
begin
  plotSize = where(isint(opt),opt,get_res_value_keep(opt,"plotSize",1))
  plot = newPlots(plotSize)
  option = True
  copy_VarAtts(opt, option)
  res = True
    res@gsnDraw = False
    res@gsnFrame = False
  exclude := (/"cn","lb","Scale","gsn","preyear","gsnStringBold","tmLabelFontHeightF","vc","gsLineThicknessF","tmXBLabelsOn"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  atts = (/"tmXBLabelsOn","tmYLLabelsOn","gsnCorner","gsnLeftString","gsnRightString","gsnCenterString","tiMain","tmYLTick"/)
  do i = 0, plotSize-1
    do a = 0, dimsizes(atts)-1
      copy_res_eq_with_index(option,res,atts(a),i)
    end do
    if(isatt(opt, "polar") .and. opt@polar)
      plot(i) = plot_polar(wks,range,res)
    else
      ; if(isatt(opt, "tmYLTickStartF"))then
      ;   opt@tmYLMode = "Manual"
      ; end if
      plot(i) = plot_base(wks,range,res)
    end if
  end do
  return plot
end

undef("add_cn")
procedure add_cn (plotid,var,range,opt)
local plot,res,tem_wks,clr,clr_pos,Scale,format,exclude
begin
  ; print(plotid)
  currentPlot = plotid@plot
  tem_wks = NhlGetParentWorkstation(plotid)
  clr = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  clr_pos = (/"#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  res = True
    ; res@gsnDraw = False
    ; res@gsnFrame = False
    if(isatt(plotid,"isShaded"))
      res@cnFillOn = .not. plotid@isShaded(currentPlot)
    else
      res@cnFillOn = True
    end if
    ; res@cnFillOn = .not. isatt(plotid, "isShaded"+currentPlot)
    res@cnLinesOn = .not. res@cnFillOn
    res@cnLineLabelsOn = False
    res@cnInfoLabelOn = False
    res@cnFillColors = clr
    ; res@cnLineColors = clr
    res@cnMonoLineColor = True
    ; res@cnLevelSelectionMode = "ExplicitLevels"
    ; res@cnLevels = (/-4,-3,-2,-1,1,2,3,4./)
    ; res@cnFillColors = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
    res@pmLabelBarOrthogonalPosF = 0.1
    ; if(isatt(plotid,"isShaded"))
    ;   res@cnLinesOn = True
    ; end if
  exclude = (/"tm","Scale","gsnStringBold","preyear","vc","gsnCorner","lbLabelFormat","gsnLeftStrings"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  if(isatt(res, "cnLevels"))then
    res@cnLevelSelectionMode = "ExplicitLevels"
    Scale = get_res_value_keep(opt,"Scale",1.)
    res@cnLevels := res@cnLevels*Scale
    if( .not. isatt(res, "lbLabelStrings") .and. typeof(res@cnLevels) .eq. "float")
      format = get_res_value_keep(opt,"lbLabelFormat","%0.2f")
      res@lbLabelStrings = sprintf(format, res@cnLevels)
    end if
  end if
  if(isatt(res, "cnLevel")) delete(res@cnLevel) end if
  res@gsnLeftString := ""
  res@gsnRightString := ""

  if(isatt(opt,"reverseColors") .and. opt@reverseColors)
    if(res@cnFillOn) res@cnFillColors = res@cnFillColors(::-1) end if
    if(res@cnLinesOn) res@cnLineColors = res@cnLineColors(::-1) end if
  end if
  if(.not. isArray(res@cnFillColors))
    if(res@cnFillColors .eq. "pos")
      res@cnFillColors := clr_pos
  end if 
  end if
  ; if(isatt(opt,"mode") .and. opt@mode .eq. "stippling")
  ;   stipplingColor = get_res_value_keep(opt,"stipplingColor","white")
  ;   res@cnFillOn = True
  ;   res@cnLinesOn = False
  ;   res@lbLabelBarOn = False
  ;   res@cnInfoLabelOn = False
  ;   res@cnMonoFillPattern = False
  ;   res@cnFillPatterns = (/-1,17,-1,17,-1/)
  ;   res@cnFillColors   := (/stipplingColor,stipplingColor,"gray",stipplingColor,stipplingColor/)
  ;   if(isatt(opt,"drawOrder"))
  ;     res@cnFillDrawOrder = opt@drawOrder
  ;   end if
  ;   res@cnFillScaleF = get_res_value_keep(opt,"cnFillScaleF",2.0)
  ;   res@cnFillDotSizeF = get_res_value_keep(opt,"cnFillDotSizeF",0.003)
  ; end if
  if(isatt(res, "cnLineColors"))
    res@cnMonoLineColor = False
  end if
  plot = gsn_csm_contour(tem_wks,var,res)
  if(res@cnFillOn)
    if(isatt(plotid,"isShaded"))
      plotid@isShaded(currentPlot) = True
    else
      plotid@isShaded = True
    end if
  end if

  ; plot = gsn_csm_pres_hgt(tem_wks,var,res)
  overlay(plotid,plot)
  ; setvalues plotid
  ;   "test"               : True
  ; end setvalues

  ; getvalues plotid
  ;   "test"               : test
  ; end getvalues
  ; print(test)
end

undef("add_dots")
procedure add_dots (plotid,var,range,opt)
local plot,tem_wks,res,exclude,dotColor,cnLevel
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  res = True
    res@gsnDraw = False
    res@gsnFrame = False
    res@cnFillOn = True
    res@cnLinesOn = False
    res@cnLineLabelsOn = False
    res@cnInfoLabelOn = False
    res@lbLabelBarOn = False
    res@cnFillDotColor = "white"
    res@cnLevelSelectionMode = "ExplicitLevels"
    res@cnFillScaleF = 2.0
    res@cnFillDotSizeF = 0.003
    res@cnLevel = 1
  exclude = (/"tm","Scale","gsnStringBold","preyear","vc","gsnCorner","lbLabelFormat"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
    res@cnFillOn = True
    res@cnLinesOn = False
    res@cnLineLabelsOn = False
    res@cnInfoLabelOn = False
    res@lbLabelBarOn = False
    res@gsnLeftString = ""
    res@gsnRightString = ""
    res@cnMonoFillPattern = False
    res@cnFillPatterns = (/-1,17,-1,17,-1/)
    dotColor = res@cnFillDotColor
    cnLevel = res@cnLevel
    res@cnLevels := (/-999.,-cnLevel,cnLevel,999./)
    res@cnFillColors   := (/dotColor,dotColor,"gray",dotColor,dotColor/)
    delete([/res@cnFillDotColor,res@cnLevel/])
  if(isatt(opt,"dotDrawOrder"))
    res@cnFillDrawOrder = opt@dotDrawOrder
  end if
  plot = gsn_csm_contour(tem_wks,var,res)
  ; plot = gsn_csm_pres_hgt(tem_wks,var,res)
  ; getvalues plot
  ;   "cnLevels"               : levels0
  ;   "cnFillColors"           : colors
  ;   "cnInfoLabelFontHeightF" : font_height
  ; end getvalues
  overlay(plotid,plot)
end

undef("add_hatching")
procedure add_hatching (plotid,var,range,opt)
local plot,tem_wks,res,exclude,dotColor,cnLevel,hatchingPattern,hatchingColor
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  hatchingPattern = get_res_value_keep(opt, "hatchingPattern", 6)
  hatchingColor = get_res_value_keep(opt, "hatchingColor", "white")
  res = True
    res@gsnDraw = False
    res@gsnFrame = False
    res@cnFillOn = True
    res@cnLinesOn = False
    res@cnLineLabelsOn = False
    res@cnInfoLabelOn = False
    res@lbLabelBarOn = False
    res@cnLevelSelectionMode = "ExplicitLevels"
    res@cnFillScaleF = 2.0
    res@cnFillDotSizeF = 0.003
    res@cnLevel = 1
  exclude = (/"tm","Scale","gsnStringBold","preyear","vc","gsnCorner","lbLabelFormat"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
    res@cnFillOn = True
    res@cnLinesOn = False
    res@cnLineLabelsOn = False
    res@cnInfoLabelOn = False
    res@lbLabelBarOn = False
    res@gsnLeftString = ""
    res@gsnRightString = ""
    res@cnMonoFillPattern = False
    ; res@cnfillt
    res@cnFillPatterns = (/-1,hatchingPattern,-1,hatchingPattern,-1/)
    cnLevel = res@cnLevel
    res@cnLevels := (/-999.,-cnLevel,cnLevel,999./)
    res@cnFillColors   := (/hatchingColor,hatchingColor,"gray",hatchingColor,hatchingColor/)
    delete([/res@cnLevel/])
  if(isatt(opt,"dotDrawOrder"))
    res@cnFillDrawOrder = opt@dotDrawOrder
  end if
  plot = gsn_csm_contour(tem_wks,var,res)
  ; plot = gsn_csm_pres_hgt(tem_wks,var,res)
  ; getvalues plot
  ;   "cnLevels"               : levels0
  ;   "cnFillColors"           : colors
  ;   "cnInfoLabelFontHeightF" : font_height
  ; end getvalues
  overlay(plotid,plot)
end

undef("add_cor")
procedure add_cor (plotid,ts,tp,range,opt)
local type,res,nyear,t,method,X,cor,res_test
begin
  type = tp
  call_add_cor = "add_cor"
  ListAppend(call_stream, call_add_cor)
  ; printc("start: add_cor","green")
  res = True
    res@cnLinesOn = False
    res@cnFillOn = True
    res@gsnDraw = False
    res@gsnFrame = False
    res@lbLabelBarOn = True
    res@lbOrientation = "Horizontal"
    res@gsnStringFontHeightF = 0.027
    res@gsnAddCyclic = (range(3)-range(2)) .eq. 360
    ; res@cnFillDrawOrder = "predraw"
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  ; opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ;plot 
  method = "anom"
  if(isatt(opt, "add_dim_to_mean"))
    method@add_dim_to_mean = opt@add_dim_to_mean
  end if
  if(isatt(opt, "detrend"))
    method@detrend = opt@detrend
  end if
  ; type@source = "jra55"
  type@year := ts&year
  ; opt@lonP0=False 
  ; opt@vertical=False
  if(isatt(opt,"polar")) range(2:3) = (/0,360/) end if
  type@range := range
  id = type
    id@type = type
    ; id@dim_to_mean = dim_to_mean
    id@call = call_add_cor
    id@ts = ts
  ; print(id)
  if(call_stream[0] .eq. call_add_cor .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
      printc("read buffer: "+call_add_cor,"blue")
      cor := read_buffer(id)
  else
    X := process(type,method) 
    ; if(isatt(opt,"multi")) X = (/X*opt@multi/) end if
      if(isatt(opt, "designal"))then
        print("designal")
        X = (/designal(X,opt@designal)/)
      end if
    cor := escorc_n(ts, X, 0, 0)
    printMinMax(cor, 1)
    copy_VarCoords_not_n( X, cor, 0)
    if((call_stream[0] .eq. call_add_cor) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(cor,id)
    end if
  end if
  cor@reverseColors    := get_res_value_keep(opt,"reverseColors",False)

  res@cnLevels := (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)

  exclude = (/"gsLine","gsnLeftStrings","gsnCornerStrings"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  res@Scale = 1
  if(isatt(opt, "reverseColors"))
    res@reverseColors = opt@reverseColors
  end if
  if(get_res_value_keep(opt,"smoothing",False));平滑
    print("smoothing")
    print("123")
    cor := smth9_Wrap(cor, 0.25, 0.5, False)
  end if
  add_cn(plotid,cor,range,res)

  res_test = get_res_value_keep(opt,"test",False)
  if(res_test)
    res_test@mode = get_res_value_keep(opt,"mode","stippling")
    res_test@cnFillDotSizeF = 0.0025
    res_test@cnFillScaleF = 1.2
    ; res_test@stipplingColor = "black"
    exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)

    copy_VarAtts_match(opt,res_test,res_plot,exclude)

    ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
    ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
    if(res_test@mode .eq. "stippling")
      if(isatt(opt,"stipplingColor"))
        res_test@stipplingColor = opt@stipplingColor
      end if
      level = get_res_value_keep(opt,"stipplingLevel",90)
      res_test@cnLevel = t@$("r"+level)$
      add_dots(plotid,cor,range,res_test)
    end if

    if(res_test@mode .eq. "contour")
      sigLevel = get_res_value_keep(opt,"sigLevel",90) 
      res_test@cnFillOn = False
      res_test@cnLinesOn = True
      res_test@lbLabelBarOn = False
      res_test@cnLevels := (/-999,-t@$("r"+sigLevel)$,t@$("r"+sigLevel)$,999/)
      res_test@gsnContourNegLineDashPattern = 0
      print(res_test@cnLevels)
      add_cn(plotid,cor,range,res_test)
    end if
  end if

end



undef("add_reg")
procedure add_reg (plotid,ts,tp,range,opt)
local type,method,res,tval,rec,t,nyear,X,exclude
  begin
  type = tp
  call_add_reg = "add_reg"
  ListAppend(call_stream, call_add_reg)
  ; printc("start: add_reg","green")
  method = "anom"
  if(isatt(opt, "add_dim_to_mean"))
    method@add_dim_to_mean = opt@add_dim_to_mean
  end if
  if(isatt(opt, "detrend"))
    method@detrend = opt@detrend
  end if
  currentPlot = plotid@plot
  res = True
    if(isatt(plotid,"shadedPlots"))
      res@cnLinesOn = is_element(currentPlot,plotid@shadedPlots)
      res@gsnContourNegLineDashPattern = 14
      res@cnLineThicknessF = 5.
    else
      res@cnLinesOn = False
    end if
    res@cnFillOn = .not. res@cnLinesOn
    res@gsnAddCyclic = (range(3)-range(2)) .eq. 360
    res@gsnDraw = False
    res@gsnFrame = False
    res@lbLabelBarOn = True
    res@lbOrientation = "Horizontal"
    res@gsnStringFontHeightF = 0.027
    res@cnLevels = (/-4.,-3,-2,-1,1,2,3,4/)
    res@Scale = 1.
  exclude = (/"gsnLeftStrings","gsnCornerStrings"/)

  copy_VarAtts_match(opt,res,res_plot,exclude)
    ; res@cnFillDrawOrder = "predraw"
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  ; opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ; type@source = "jra55"
  type@year := ts&year
  ; type@range := range
  type@ts = ts
  ; opt@lonP0=False 
  ; opt@vertical=False
  ; if(isatt(opt,"polar")) range(2:3) = (/0,360/) end if
  id = type
    id@type = type
    ; id@dim_to_mean = dim_to_mean
    id@call = call_add_reg
    if(isatt(opt,"add_dim_to_mean"))
      id@add_dim_to_mean = opt@add_dim_to_mean
    end if
  if(call_stream[0] .eq. call_add_reg .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
      printc("read buffer: "+call_add_reg,"blue")
      rec := read_buffer(id)
  else
    if(isatt(opt, "focusIA"))then
      type@year := ispan(1950, 2022, 1)
      X := process(type,method)
      tem := bandpass(X,10,200,True)
      rec := regCoef_n(ts, tem({ts&year},:,:), 0, 0)
    else
      X := process(type,method)
      if(isatt(opt, "designal"))then
        print("designal")
        X = (/designal(X,opt@designal)/)
      end if
      rec := regCoef_n(ts, X, 0, 0)
    end if
    if(isatt(opt, "relative") .and. opt@relative)then
      method = "stddev"
      X_clim = process(type,method)
      tem := where(X_clim .eq. 0, X_clim@_FillValue, X_clim)
      rec = (/rec/tem/)
      rec@units = "%"
    end if
    ; printVarSummary(X)
    copy_VarCoords_not_n( X, rec, 0)

    if((call_stream[0] .eq. call_add_reg) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(rec,id)
    end if
  end if
  if(isatt(opt,"multi")) rec = (/rec*opt@multi/) end if
  tval = get_tval(rec)
  if(get_res_value_keep(opt,"smoothing",False));平滑
    rec := smth9_Wrap(rec, 0.25, 0.5, False)
  end if

  if(get_res_value_keep(opt,"onlySignificant",False));只画显著区域
    rec_sig = where(abs(tval) .ge. t@t90,rec,rec@_FillValue)
    rec = (/rec_sig/)
  end if
  ; cor := smth9_Wrap(cor, 0.5, 0., False)

  ; cor@cnLevels         = (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)
    ; cor@cnLevels         = (/-0.9,-0.7,-0.5,-0.3,0.3,0.5,0.7,0.9/)
  ; cor@cnLevels         := (/-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99/)

  ; rec@cnFillColors = (/clr(0),clr(1),clr(3),clr(4),clr(5),clr(7),clr(8)/)

  ; res@cnLevels := (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)


  res@gsnLeftString = ""
  if(isatt(opt,"reverseColors")) res@reverseColors = opt@reverseColors end if
  add_cn(plotid,rec,range,res)

  res_test = get_res_value_keep(opt,"test",True)
  if(res_test)
    res_test@mode = get_res_value_keep(opt,"mode","stippling")
    res_test@cnFillDotSizeF = 0.0025
    res_test@cnFillScaleF := 1.2
    ; res_test@stipplingColor = "black"
    exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)

    copy_VarAtts_match(opt,res_test,res_plot,exclude)
    ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
    ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
    if(res_test@mode .eq. "stippling")
      res_test@cnFillOn = True
      if(isatt(opt,"stipplingColor"))
        res_test@cnFillDotColor = opt@stipplingColor
        ; print(res_test@stipplingColor)
      end if
      if(isatt(opt, "cnFillDotOpacityF"))then
        res_test@cnFillOpacityF = opt@cnFillDotOpacityF
      end if
      if(isatt(opt, "dotDrawOrder"))then
        res_test@dotDrawOrder = opt@dotDrawOrder
        ; print(opt@dotDrawOrder)
      end if
      level = get_res_value_keep(opt,"stipplingLevel",90)
      res_test@cnLevel = t@$("t"+level)$
      add_dots(plotid,tval,range,res_test)
    end if

    if(res_test@mode .eq. "contour")
      sigLevel = get_res_value_keep(opt,"sigLevel",90) 
      res_test@cnFillOn = False
      res_test@cnLinesOn = True
      res_test@lbLabelBarOn = False
      res_test@cnLevels := (/-999,-t@$("t"+sigLevel)$,t@$("t"+sigLevel)$,999/)
      res_test@gsnContourNegLineDashPattern = 0
      add_cn(plotid,tval,range,res_test)
    end if
    if(res_test@mode .eq. "hatching")then
      sigLevel = get_res_value_keep(opt,"sigLevel",90) 
      res_test = get_res_eq(opt,"hatching")
      res_test@cnFillOn = True
      res_test@cnLevel = t@$("t"+sigLevel)$
      print(res_test)
      add_hatching(plotid,tval,range,res_test)
      add_hatching(plotid,tval,range,res_test)
      add_hatching(plotid,tval,range,res_test)
      add_hatching(plotid,tval,range,res_test)
      add_hatching(plotid,tval,range,res_test)
    end if
  end if
end

undef("add_explainedVar")
procedure add_explainedVar (plotid,ts,tp,range,opt)
local type,res,nyear,t,method,X,cor,res_test
begin
  type = tp
  call_add_explainedVar = "add_explainedVar"
  ListAppend(call_stream, call_add_explainedVar)
  ; printc("start: add_explainedVar","green")
  res = True
    res@cnLinesOn = False
    res@cnFillOn = True
    res@gsnDraw = False
    res@gsnFrame = False
    res@lbLabelBarOn = True
    res@lbOrientation = "Horizontal"
    res@gsnStringFontHeightF = 0.027
    res@gsnAddCyclic = (range(3)-range(2)) .eq. 360
    ; res@cnFillDrawOrder = "predraw"
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  ; opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ;plot 
  method = "anom"
  if(isatt(opt, "add_dim_to_mean"))
    method@add_dim_to_mean = opt@add_dim_to_mean
  end if
  if(isatt(opt, "detrend"))
    method@detrend = opt@detrend
  end if
  ; type@source = "jra55"
  type@year := ts&year
  ; opt@lonP0=False 
  ; opt@vertical=False
  if(isatt(opt,"polar")) range(2:3) = (/0,360/) end if
  type@range := range
  id = type
    id@type = type
    ; id@dim_to_mean = dim_to_mean
    id@call = call_add_explainedVar
    id@ts = ts
  ; print(id)
  if(call_stream[0] .eq. call_add_explainedVar .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
      printc("read buffer: "+call_add_explainedVar,"blue")
      ev := read_buffer(id)
  else
    X := process(type,method) 
    ; if(isatt(opt,"multi")) X = (/X*opt@multi/) end if

    cor := escorc_n(ts, X, 0, 0)
    ev := cor^2
    copy_VarCoords_not_n( X, ev, 0)
    if((call_stream[0] .eq. call_add_explainedVar) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(ev,id)
    end if
  end if
  ev@reverseColors    := get_res_value_keep(opt,"reverseColors",False)

  res@cnLevels := (/0.1,0.2,0.25,0.3,0.35,0.4,0.45,0.5/)
  res@cnFillColors = (/"#FFFFFF","#F6B8AA","#F28D75","#EE6B54","#EA463B","#E82229","#BE252B","#871E20","#6B1014"/)

  exclude = (/"gsLine","gsnLeftStrings","gsnCornerStrings"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  res@Scale = 1
  add_cn(plotid,ev,range,res)
end

undef("add_trend")
procedure add_trend (plotid,tp,range,opt)
local option,type,ts
begin
  option = opt
    ; option@multi = get_res_value_keep(opt,"trend_")
  type = tp
  ts = type@year
  setDim(ts,0,"year",ts)
  add_reg(plotid,ts,type,range,option)
end


undef("add_reg_JA_HW")
procedure add_reg_JA_HW (plotid,ts,type,range,opt)
begin
    type@year := ts&year
    type@range := range
  tmax = read_JA_HW (type,opt)
  rec = regCoef_n(ts, tmax, 0, 0)
  copy_VarCoords(tmax(0,:,:), rec)
  tval = get_tval(rec)
  if(get_res_value_keep(opt,"smoothing",False));平滑
    rec := smth9_Wrap(rec, 0.5, 0.5, False)
  end if

  if(get_res_value_keep(opt,"onlySignificant",False));只画显著区域
    rec_sig = where(abs(tval) .ge. t@t90,rec,rec@_FillValue)
    rec = (/rec_sig/)
  end if
  if(isatt(opt,"multi")) rec = (/rec*opt@multi/) end if
  currentPlot = plotid@plot
  res = True
    if(isatt(plotid,"shadedPlots"))
      res@cnLinesOn = is_element(currentPlot,plotid@shadedPlots)
      res@gsnContourNegLineDashPattern = 14
      res@cnLineThicknessF = 5.
    else
      res@cnLinesOn = False
    end if
    res@cnFillOn = .not. res@cnLinesOn
    res@gsnAddCyclic = (range(3)-range(2)) .eq. 360
    res@gsnDraw = False
    res@gsnFrame = False
    res@lbLabelBarOn = True
    res@lbOrientation = "Horizontal"
    res@gsnStringFontHeightF = 0.027
    res@cnLevels = (/-4.,-3,-2,-1,1,2,3,4/)
    res@Scale = 1.
  exclude = (/"gsnLeftStrings","gsnCornerStrings"/)
  if(isatt(opt,"reverseColors")) res@reverseColors = opt@reverseColors end if
  copy_VarAtts_match(opt,res,res_plot,exclude)
  add_cn(plotid,rec,range,res)
  res_test = get_res_value_keep(opt,"test",True)
  if(res_test)
    t = t_value(dimsizes(type@year)-2)
    res_test@mode = get_res_value_keep(opt,"mode","stippling")
    res_test@cnFillDotSizeF = 0.0025
    res_test@cnFillScaleF = 1.2
    ; res_test@stipplingColor = "black"
    exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)

    copy_VarAtts_match(opt,res_test,res_plot,exclude)

    ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
    ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
    if(res_test@mode .eq. "stippling")
      if(isatt(opt,"stipplingColor"))
        res_test@stipplingColor = opt@stipplingColor
      end if
      res_test@cnLevel = t@t90
      add_dots(plotid,tval,range,res_test)
    end if

    if(res_test@mode .eq. "contour")
      res_test@cnFillOn = False
      res_test@cnLinesOn = True
      res_test@lbLabelBarOn = False
      res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
      add_cn(plotid,tval,range,res_test)
    end if
  end if
end

undef("add_reg_JA_HW")
procedure add_reg_JA_HW (plotid,ts,type,range,opt)
begin
    type@year := ts&year
    type@range := range
  tmax = read_JA_HW (type,opt)
  rec = regCoef_n(ts, tmax, 0, 0)
  copy_VarCoords(tmax(0,:,:), rec)
  tval = get_tval(rec)
  if(get_res_value_keep(opt,"smoothing",False));平滑
    rec := smth9_Wrap(rec, 0.5, 0.5, False)
  end if

  if(get_res_value_keep(opt,"onlySignificant",False));只画显著区域
    rec_sig = where(abs(tval) .ge. t@t90,rec,rec@_FillValue)
    rec = (/rec_sig/)
  end if
  if(isatt(opt,"multi")) rec = (/rec*opt@multi/) end if
  currentPlot = plotid@plot
  res = True
    if(isatt(plotid,"shadedPlots"))
      res@cnLinesOn = is_element(currentPlot,plotid@shadedPlots)
      res@gsnContourNegLineDashPattern = 14
      res@cnLineThicknessF = 5.
    else
      res@cnLinesOn = False
    end if
    res@cnFillOn = .not. res@cnLinesOn
    res@gsnAddCyclic = (range(3)-range(2)) .eq. 360
    res@gsnDraw = False
    res@gsnFrame = False
    res@lbLabelBarOn = True
    res@lbOrientation = "Horizontal"
    res@gsnStringFontHeightF = 0.027
    res@cnLevels = (/-4.,-3,-2,-1,1,2,3,4/)
    res@Scale = 1.
  exclude = (/"gsnLeftStrings","gsnCornerStrings"/)
  if(isatt(opt,"reverseColors")) res@reverseColors = opt@reverseColors end if
  copy_VarAtts_match(opt,res,res_plot,exclude)
  add_cn(plotid,rec,range,res)
  res_test = get_res_value_keep(opt,"test",True)
  if(res_test)
    t = t_value(dimsizes(type@year)-2)
    res_test@mode = get_res_value_keep(opt,"mode","stippling")
    res_test@cnFillDotSizeF = 0.0025
    res_test@cnFillScaleF = 1.2
    ; res_test@stipplingColor = "black"
    exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)

    copy_VarAtts_match(opt,res_test,res_plot,exclude)

    ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
    ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
    if(res_test@mode .eq. "stippling")
      if(isatt(opt,"stipplingColor"))
        res_test@stipplingColor = opt@stipplingColor
      end if
      res_test@cnLevel = t@t90
      add_dots(plotid,tval,range,res_test)
    end if

    if(res_test@mode .eq. "contour")
      res_test@cnFillOn = False
      res_test@cnLinesOn = True
      res_test@lbLabelBarOn = False
      res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
      add_cn(plotid,tval,range,res_test)
    end if
  end if
end

undef("add_polygon")
procedure add_polygon (plotid,opt)
  begin
  tem_wks = NhlGetParentWorkstation(plotid)
  ; opt@LineThicknessF = 10
  str = unique_string("polygon")
  res = True
  res@gsLineColor = "firebrick1"
  res@gsLineThicknessF = 5.0
  exclude = ""
  copy_VarAtts_match(opt,res,res_plot,exclude)
  if(isatt(opt, "mode"))
    if(opt@mode .eq. "fill")
      plotid@$str$ = gsn_add_polygon(tem_wks, plotid, opt@lon, opt@lat, res)
    elseif(opt@mode .eq. "line")
      plotid@$str$ = gsn_add_polyline(tem_wks, plotid, opt@lon, opt@lat, res)
    elseif(opt@mode .eq. "both")
      plotid@$str$ = gsn_add_polyline(tem_wks, plotid, opt@lon, opt@lat, res)
      str = unique_string("polygon")
      plotid@$str$ = gsn_add_polygon(tem_wks, plotid, opt@lon, opt@lat, res)
    end if
  else
    plotid@$str$ = gsn_add_polyline(tem_wks, plotid, opt@lon, opt@lat, res)
  end if

end

undef("add_clim")
procedure add_clim (plotid:graphic,type,range,opt)
local clim,tmp_wks,option,tem_type,i
begin
  tmp_wks = NhlGetParentWorkstation(plotid(0))
  tem_type = type
  option = "clim"
  option@gsnDraw = False
  option@gsnFrame = False
  if(isatt(opt, "clim"))then
    option@clim = opt@clim
  end if
  if(isatt(opt, "reverseColors"))then
    option@reverseColors = opt@reverseColors
  end if
  if(isatt(opt, "add_dim_to_mean"))then
    option@add_dim_to_mean = opt@add_dim_to_mean
  end if
  tem_type@range := range
  if(isatt(option, "Scale"))
    delete(option@Scale)
  end if
  copy_VarAtts_match(tem_type,option,"cn","")
  clim = process(tem_type,option)
  copy_VarAtts_match(opt,option,(/"cn","lb","pm"/),"")
  if(isatt(opt, "multi"))
    clim = (/clim*opt@multi/)
  end if
  if(isatt(opt, "offset"))
    clim = (/clim+opt@offset/)
  end if
  if(isatt(opt, "Scale"))
    option@Scale = opt@Scale
  end if
  do i = 0, dimsizes(plotid)-1
    add_cn(plotid(i),clim,range,option)
  end do

end

undef("add_clim_dev")
procedure add_clim_dev (plotid:graphic,type,range)
local tmp_wks,tem_type,option,clim,i
begin
  tmp_wks = NhlGetParentWorkstation(plotid(0))
  tem_type = type
  method = "clim"
  if(isatt(type,"add_dim_to_mean"))
    method@add_dim_to_mean = type@add_dim_to_mean
  end if
  option = True
  option@gsnDraw = False
  option@gsnFrame = False
  tem_type@range := range
  if(isatt(option, "Scale"))
    delete(option@Scale)
  end if
  copy_VarAtts_match(tem_type,option,"cn","")
  clim = process(tem_type,method)
  if(isatt(type, "multi"))
    clim = (/clim*type@multi/)
  end if
  do i = 0, dimsizes(plotid)-1
    add_cn(plotid(i),clim,range,option)
  end do
end

undef("add_clim_ver_dev")
procedure add_clim_ver_dev (plotid:graphic,type)
  begin
  tmp_wks = NhlGetParentWorkstation(plotid)
  res = True
  res@gsnDraw = False
  res@gsnFrame                 = False
  res@method = "clim"
  res@dim_to_avg = type@dim_to_avg
  clim = process(type,res)
  res@gsnPresHgtHeightLabelOn = False
  res@cnInfoLabelOn     = False ;turn off contour information label
  res@cnLineLabelsOn    = False
  res@lbLabelBarOn      = False
  res@cnMonoFillPattern = False
  res@cnLevelSelectionMode = "ExplicitLevels"
  res@cnLevels          = get_res_value_keep(type,"cnLevels",ispan(-4,4,1))
  
  plot_mode = get_res_value_keep(type,"plot_mode","contour")
  if(plot_mode .eq. "contour")
    res@cnLineColor      = get_res_value_keep(type,"cnLineColor","firebrick1")
    res@cnLinesOn        = True
    res@cnLineThicknessF = get_res_value_keep(type,"cnLineThicknessF", 10.)
    ; if(isatt(opt,"cnLineThicknesses"))
    ;   res@cnLineThicknesses = opt@cnLineThicknesses
    ;   res@cnMonoLineThickness = False
    ; else
    ;   res@cnLineThicknessF = get_res_value_keep(opt,"cnLineThicknessF",15.)
    ; end if
    res@cnFillOn         = False
    res@cnLineDashPattern = get_res_value_keep(type,"cnLineDashPattern",0)
    res@cnLineDrawOrder = "postdraw"
  else if(plot_mode .eq. "shading")
    res@cnLinesOn = False
    res@cnFillOn = True
    cnFillColor = get_res_value_keep(type,"cnFillColor","firebrick1")
    res@cnFillPatterns = (/-1,0,0/)
    res@cnFillColors = (/"#ffffff",cnFillColor,cnFillColor/)
    res@cnFillOpacityF  = .3
    res@cnFillDrawOrder = "postdraw"
  end if
  end if
  res@gsnLeftString   = ""
  res@gsnRightString = ""
  res@tmXBOn          = False
  res@tmYLOn          = False
  delete([/res@method,res@dim_to_avg/])

  plot = gsn_csm_pres_hgt(tmp_wks, clim, res)
  overlay(plotid, plot)
end

undef("add_vc_dev"); FX| add_vc_dev
procedure add_vc_dev (plotid:graphic,x,y,ranges,opt)
local wks,plot,clr,res
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  ; t     = t_value(opt@nyear-2)
  resw                            = True
  resw@gsnDraw = False
  resw@gsnFrame = False
  resw@vcLevelSelectionMode       = "ManualLevels"
  resw@vcGlyphStyle = "CurlyVector"
  resw@vcFillArrowHeadXF = 1.0
  resw@vcRefLengthF = 0.08
  resw@vcRefMagnitudeF = 30
  resw@vcRefAnnoOn = True
  resw@vcRefAnnoPerimThicknessF = 5
  resw@vcRefAnnoPerimOn = True
  resw@vcRefAnnoFontHeightF = 0.02
  resw@vcLevelSpacingF = 5
  resw@vcLineArrowHeadMaxSizeF = 0.015
  resw@vcLineArrowHeadMinSizeF = 0.08
  resw@vcLineArrowThicknessF    = 8
  resw@vcMonoFillArrowFillColor   = True
  resw@vcMinMagnitudeF            = 0.01
  resw@vcMinDistanceF             = 0.032
  resw@gsnLeftString              = ""
  resw@gsnRightString             = ""
  resw@vcRefAnnoOrthogonalPosF    = -1.
  resw@vcRefAnnoParallelPosF    = 1.
  resw@vcLineArrowColor = "firebrick1"
  ; resw@vcVectorDrawOrder = "postdraw"

  exclude = (/"cn","tm","gsn","Scale","preyear"/)
  copy_VarAtts_match(opt,resw,res_plot,exclude)

  if(resw@vcRefAnnoPerimThicknessF .eq. 0)
    resw@vcRefAnnoPerimOn = False
  end if
  if(.not. resw@vcRefAnnoPerimOn)
    resw@vcRefAnnoBackgroundColor = -1
  end if
  

  if(isatt(opt,"vcRefAnnoString2"))
    resw@vcRefAnnoString2 = opt@vcRefAnnoString2
    resw@vcRefAnnoString2On = True
  else
    resw@vcRefAnnoString2On = False
  end if
  if(isatt(opt,"vcRefAnnoString1"))
  ; printx(optw@vcRefAnnoString1)
    resw@vcRefAnnoString1 = opt@vcRefAnnoString1
  end if
  if(isatt(opt,"unit"))
    resw@vcRefAnnoString1 = resw@vcRefMagnitudeF+opt@unit
  end if
  if(isatt(opt,"vvScale"))
    y = (/y*opt@vvScale/)
  end if
  if(resw@vcGlyphStyle .eq. "CurlyVector")then
    vcMag = wind_speed(x, y)
    x = (/where(vcMag .lt. resw@vcMinMagnitudeF, 0, x)/)
    y = (/where(vcMag .lt. resw@vcMinMagnitudeF, 0, y)/)
  end if
  plot = gsn_csm_vector(tem_wks, x, y, resw)
overlay(plotid, plot)
end

undef("add_vc_color")
procedure add_vc_color (plotid:graphic, x, y, data, range, opt)
local tem_wks,resw,plot
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  ; t     = t_value(opt@nyear-2)
  resw = True
    resw@gsnDraw = False
    resw@gsnFrame = False
    ; resw@vcLevelSelectionMode       = "ManualLevels"
    resw@vcGlyphStyle = "CurlyVector"
    ; resw@vcGlyphStyle = "WindBarb"
    ; resw@vcMonoWindBarbColor = False
    resw@vcWindBarbLineThicknessF = 1.5
    resw@vcFillArrowHeadXF = 1.0
    resw@vcRefLengthF = 0.08
    resw@vcRefMagnitudeF = 30
    resw@vcRefAnnoOn = True
    resw@vcRefAnnoPerimThicknessF = 5
    resw@vcRefAnnoPerimOn = True
    resw@vcRefAnnoFontHeightF = 0.02
    resw@vcLevelSpacingF = 5
    resw@vcLineArrowHeadMaxSizeF = 0.015
    resw@vcLineArrowHeadMinSizeF = 0.08
    resw@vcLineArrowThicknessF    = 8
    resw@vcMonoFillArrowFillColor   = True
    resw@vcMinMagnitudeF            = 0.01
    resw@vcMinDistanceF             = 0.032
    resw@gsnLeftString              = ""
    resw@gsnRightString             = ""
    resw@vcRefAnnoOrthogonalPosF    = -1.
    resw@vcRefAnnoParallelPosF    = 1.
    ; resw@vcMapDirection = False
    resw@vcLevelSelectionMode = "ExplicitLevels"
    resw@vcLineArrowColor = "firebrick1"
    ; resw@vcGlyphOpacityF = 0.5
  ; resw@vcVectorDrawOrder = "postdraw"

  exclude = (/"cn","tm","gsn","Scale","preyear","vcColorsOn"/)
  copy_VarAtts_match(opt,resw,res_plot,exclude)
  resw@vcLevelColors = (/resw@vcLineArrowColor,"gray",resw@vcLineArrowColor/)

  if(resw@vcRefAnnoPerimThicknessF .eq. 0)
    resw@vcRefAnnoPerimOn = False
  end if
  if(.not. resw@vcRefAnnoPerimOn)
    resw@vcRefAnnoBackgroundColor = -1
  end if
  

  if(isatt(opt,"vcRefAnnoString2"))
    resw@vcRefAnnoString2 = opt@vcRefAnnoString2
    resw@vcRefAnnoString2On = True
  else
    resw@vcRefAnnoString2On = False
  end if
  if(isatt(opt,"vcRefAnnoString1"))
  ; printx(optw@vcRefAnnoString1)
    resw@vcRefAnnoString1 = opt@vcRefMagnitudeF+opt@vcRefAnnoString1
  end if
  if(isatt(opt,"unit"))
    resw@vcRefAnnoString1 = resw@vcRefMagnitudeF+opt@unit
  end if
  if(isatt(opt,"vvScale"))
    y = (/y*opt@vvScale/)
  end if
  ; plot = gsn_csm_vector(tem_wks, x, y, resw)
  plot = gsn_csm_vector_scalar(tem_wks, x, y, data, resw)
  overlay(plotid, plot)
end

undef("add_reg_vc")
procedure add_reg_vc (plotid:graphic, ts, type, range, opt)
local tem_wks,clr,res,type_x,type_y,nyear,t,x,y,rec_x,rec_y,tmax
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  clr = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  res = True
  type@year := ts&year
  ; type@range := range
  type_x = type
  type_y = type
  if(type .eq. "wind")
    type_x = "u"
    type_y = "v"
    opt@unit = " m s~S~-1~N~"
  elseif(type .eq. "wind_surface")
    type_x = "u10m"
    type_y = "v10m"
    opt@unit = " m s~S~-1~N~"
  elseif(type .eq. "water_vapor_flux" .or. type .eq. "wvf")
    type_x = "qu"
    type_y = "qv"
    opt@unit =  " kg m~S~-1~N~ s~S~-1~N~"
  end if
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  ; opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ;plot 
  x = process(type_x,opt)
  y = process(type_y,opt)

  rec_x := regCoef_n(ts, x, 0, 0)
  rec_y := regCoef_n(ts, y, 0, 0)

  t_x           = abs(onedtond(rec_x@tval, dimsizes(rec_x)))
  t_y           = abs(onedtond(rec_y@tval, dimsizes(rec_y)))
  t_max = where(t_y .ge. t_x, t_y, t_x)
  copy_VarCoords(x(0,:,:), rec_y)
  copy_VarCoords(y(0,:,:), rec_x)
  copy_VarCoords(x(0,:,:), t_max)
  if(isatt(opt,"vcColorsOn") .and. opt@vcColorsOn)
    opt@vcLevels = (/-t@t90,t@t90/)
    add_vc_color(plotid,rec_x,rec_y,t_max,range,opt)
  else
    if(isatt(opt, "test") .and. opt@test)then
      rec_y = where(t_max .le. t@t90, 0,rec_y)
      rec_x = where(t_max .le. t@t90, 0,rec_x)
    end if
    copy_VarCoords(x(0,:,:), rec_y)
    copy_VarCoords(y(0,:,:), rec_x)
    add_vc_dev(plotid,rec_x,rec_y,range,opt)
  end if
end

undef("add_reg_vc_ver")
procedure add_reg_vc_ver (plotid:graphic, ts, type, range, opt)
local tem_wks,clr,method,res,type_x,type_z,nyear,t,X,Z,rec_x,rec_z
  begin
  ; call_add_reg_vc_ver = "add_reg_vc_ver"
  ; ListAppend(call_stream, call_add_reg_vc_ver)
  tem_wks = NhlGetParentWorkstation(plotid)
  clr = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  method = get_res_value_keep(opt,"method","anom")
    method@add_dim_to_mean = opt@add_dim_to_mean
  res = True
  type@year := ts&year
  type_x = type
  type_z = type
  if(is_element("lon",opt@add_dim_to_mean))
    type_x = "v"
  else if(is_element("lat",opt@add_dim_to_mean))
    type_x = "u"
  end if  end if
  type_z = "vv"
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  ; opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ;plot 
  X = process(type_x,method)
  Z = process(type_z,method)
  rec_x := regCoef_n(ts, X, 0, 0)
  rec_z := regCoef_n(ts, Z, 0, 0)

  t_x = get_tval(rec_x)
  t_z = get_tval(rec_z)

  t_x_abs = abs(t_x)
  t_z_abs = abs(t_z)

  ; t_x           = abs(onedtond(rec_x@tval, dimsizes(rec_x)))
  ; t_z           = abs(onedtond(rec_z@tval, dimsizes(rec_z)))
  t_max = where(t_z_abs .ge. t_x_abs, t_z_abs, t_x_abs)
  ; t_max = t_z
  copy_VarCoords(X(0,:,:), rec_z)
  copy_VarCoords(Z(0,:,:), rec_x)
  copy_VarCoords(X(0,:,:), t_max)

  if(isatt(opt,"vcColorsOn") .and. opt@vcColorsOn)
    opt@vcLevels = (/-t@t90,t@t90/)
    add_vc_color(plotid,rec_x,rec_z,t_max,range,opt)
  else
    rec_z = where(t_max .le. t@t90, rec_z@_FillValue,rec_z)
    rec_x = where(t_max .le. t@t90, rec_x@_FillValue,rec_x)
    copy_VarCoords(X(0,:,:), rec_z)
    copy_VarCoords(Z(0,:,:), rec_x)
    add_vc_dev(plotid,rec_x,rec_z,range,opt)
  end if
end



undef("add_waf_dev")
procedure add_waf_dev (plotid:graphic,ts,tp,range,opt)
local dRange,type,tem_wks,res,Top,Bottom,id,reg_Fx,reg_Fy,nccuvar,nccvvar,tem_u,tem_v,cuvar,type_strm,cuvar,cvvar,plot,ftmp,lattmp,H,tem_avg,method,lat
begin
dRange = tp@range
type = tp
  call_add_waf_dev = "add_waf_dev"
  ListAppend(call_stream, call_add_waf_dev)
  printc("start: add_waf_dev","green")
  tem_wks = NhlGetParentWorkstation(plotid)
  ; range = (/ranges(0),ranges(1) ,ranges(2)-5,ranges(3)+5/)
res = True
  res@vcRefLengthF             = 0.06
  res@vcRefMagnitudeF          = 2.
  res@vcMinMagnitudeF          = 0.15
  res@vcRefAnnoOrthogonalPosF = -1.148
  res@vcLineArrowThicknessF    = 8.
  res@vcMaxMagnitudeF          = 20
  res@vcLineArrowColor         = "black"
  res@vcMinDistanceF           = 0.02
  res@vcLineArrowHeadMaxSizeF  = 0.1
  res@vcLineArrowHeadMinSizeF  = 0.004
  res@vcRefAnnoPerimThicknessF = 1.
  res@vcRefAnnoPerimOn = True
  res@vcRefAnnoFontHeightF = 0.02

  res=get_res_eq(opt,(/"vc","gsn"/))
  res@vcLevelSelectionMode = "ManualLevels"
  res@vcGlyphStyle             = "LineArrow"
  ; res@vcGlyphStyle             = "CurlyVector"
  res@vcLevelSpacingF          = 0.5

  res@vcMonoFillArrowFillColor = True
  res@gsnLeftString            = ""
  res@vcRefAnnoString2On = False
  res@gsnLeftString = ""
  Top = (/"top","Top","TOP"/)
  Bottom = (/"bottom","Bottom","BOTTOM"/)
  if(is_element(res@vcRefAnnoPosition,Top))
    res@vcRefAnnoString1On = True
    res@vcRefAnnoString2On = False
    res@vcRefAnnoString1 = res@vcRefMagnitudeF+" m~S~2~N~ s~S~-2~N~"
  elseif(is_element(res@vcRefAnnoPosition,Bottom))
    res@vcRefAnnoString1On = False
    res@vcRefAnnoString2On = True
    res@vcRefAnnoString2 = res@vcRefMagnitudeF+" m~S~2~N~ s~S~-2~N~"
  end if
  res@gsnDraw = False
  res@gsnFrame = False
  ; res@vcLineArrowColor         = "firebrick2"
  res@vcVectorDrawOrder = "postdraw"
  ; res@vcRefAnnoOrthogonalPosF = -1.041
  res@gsnRightString=""
  if(res@vcRefAnnoPerimThicknessF .eq. 0)
    res@vcRefAnnoPerimOn = False
  end if
  if(.not. res@vcRefAnnoPerimOn)
    res@vcRefAnnoBackgroundColor = -1
  end if
copy_VarAtts_match(opt,res,res_plot,"")
  type@year := ts&year
  id = type
    id@call = call_add_waf_dev
    id@range := range
if(call_stream[0] .eq. call_add_waf_dev .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
  printc("read buffer: "+call_add_waf_dev,"blue")
  reg_Fx = read_buffer(id)
  reg_Fy = read_buffer(id)
      ; return(read_buffer)
  ; end if
; if(isBegin(call_add_waf_dev))
;   bufferName = bufferPath+"buffer"+bufferCount
;   ; printc("buffer"+bufferCount,"yellow")
;   bufferCount = bufferCount+1
;   ; system("rm -rf "+bufferName+".nc")
;   fin = addfile(bufferName+".nc", "r")
;   reg_Fx = fin->temx
;   reg_Fy = fin->temy
else
  if(type@source .eq. "jra55" .or. type@source .eq. "JRA55")
  nccuvar  = addfile(localpath(2)+"jra55/u/u.ltm.nc","r")
  nccvvar  = addfile(localpath(2)+"jra55/v/v.ltm.nc","r")
  ; ncpsidev = addfile(path+"jra55-psidev.monthly.nc","r")
  tem_u= nccuvar->u(type@month-1,{type@level},{dRange(0):dRange(1)},:)
  tem_v= nccvvar->v(type@month-1,{type@level},{dRange(0):dRange(1)},:)
  end if

  if(dRange(2) .lt. 0)
    tem_u := lonPivot(tem_u,dRange(2)+360)
    tem_v := lonPivot(tem_v,dRange(2)+360)
  end if
  if(dimsizes(type@month) .eq. 1)
    cuvar = tem_u(:,{dRange(2):dRange(3)})
    cvvar = tem_v(:,{dRange(2):dRange(3)})
  else
    cuvar = dim_avg_n_Wrap(tem_u(:,:,{dRange(2):dRange(3)}), 0)
    cvvar = dim_avg_n_Wrap(tem_v(:,:,{dRange(2):dRange(3)}), 0)
  end if

  type_strm = "strm"
  type_strm@source = "jra55"
  copy_VarAtts(type,type_strm)
  type_strm@range := type@range
  opt@method = get_res_value_keep(opt,"method","TN")
  if(opt@method .eq. "plumb")
    ranges = (/range(0),range(1),0,360/)
    ; range(2:3) = (/0,360/)
    tem_avg := process(type_strm,opt)
    tem_avg := dim_rmvmean_n_Wrap(tem_avg,1)
    H = tem_avg({ts&year},:,{range(2):range(3)})
  elseif(opt@method .eq. "TN")
    method = "anom"
    tem_avg := process(type_strm,method)
    ; printVarSummary(method)
    H = tem_avg({ts&year},:,:)
  end if


  cumag = sqrt(cuvar^2 + cvvar^2)
  cumag@_FillValue = cuvar@_FillValue
  cumag = where(cumag .gt. 0, cumag, cumag@_FillValue)
  
  re = 6378388
  ; pi = atan(1.0)*4.
  pi = get_pi("float")
  lat = tem_avg&lat
  lon = tem_avg&lon
  time = tem_avg&year
  coslat = cos(lat*pi/180.)
  ga=9.80665

; Coriolis parameter
  f =  2.*2.*pi/(60.*60.*24.)*sin(pi/180. * lat)
  f!0 = "lat"
  f&lat = lat
  f@_FillValue = -1.e+21
  nlat = dimsizes(lat)
  nlon = dimsizes(lon)
  do ilat = 0, nlat-1
    if (abs(lat(ilat) ).lt. 10. ) then
      f(ilat)= f@_FillValue
    end if
  end do
  ftmp = conform_dims(dimsizes(H),f,1)
  lattmp = conform_dims(dimsizes(ftmp),lat,1)
  ftmp = where(lattmp .lt. 10,ftmp@_FillValue,ftmp)
  psidev = H;*ga/ftmp
  ; if(opt@method .eq. "plumb")
  ;   psidev := dim_rmvmean(psidev)
  ; end if

  reg_psidev = regCoef_n(ts, psidev, 0, 0)
  ; printMinMax(reg_psidev,0)

  copy_VarCoords(psidev(0,:,:), reg_psidev)
  coslattmp = conform_dims(dimsizes(reg_psidev),coslat,0)
  lattmp := conform_dims(dimsizes(reg_psidev),lat,0)
  reg_psidev = where(lattmp .lt. 10,reg_psidev@_FillValue,reg_psidev)
  ;psidev_tval = onedtond(reg_psidev@tval, dimsizes(reg_psidev))
  

  ; QG stream function for anomaly
  ;dpsidev/dlon
  dpsidevdlon =  center_finite_diff_n(reg_psidev,lon*pi/180.,True,0,1)
  
  ;ddpsidev/dlonlon
  ddpsidevdlonlon =  center_finite_diff_n(dpsidevdlon,lon*pi/180.,True,0,1)
  
  ;dpsidev/dlat
  dpsidevdlat = center_finite_diff_n(reg_psidev, lat*pi/180., False,0,0)
  
  ;ddpsidev/dlonlat
  ddpsidevdlonlat =  center_finite_diff_n(dpsidevdlon,lat*pi/180.,False,0,0)
  
  ;ddpsidev/dlatdlat
  ddpsidevdlatlat = center_finite_diff_n(dpsidevdlat, lat*pi/180.,False,0,0)
  xuterm = (dpsidevdlon*dpsidevdlon - reg_psidev*ddpsidevdlonlon)
  xvterm = (dpsidevdlon*dpsidevdlat - reg_psidev*ddpsidevdlonlat)
  ;yuterm = xvterm
  yvterm = (dpsidevdlat*dpsidevdlat - reg_psidev*ddpsidevdlatlat)
  ; printMinMax(xuterm,0)
  if(opt@method .eq. "TN")
    tem := type@level/1000. /(2.*cumag*re*re)
    reg_Fx = type@level/1000./(2.*cumag*re*re)*( cuvar/coslattmp * xuterm + cvvar * xvterm)
    reg_Fy = type@level/1000./(2.*cumag*re*re)*( cuvar*xvterm + coslattmp*cvvar*yvterm)
  ;Fz = leveltmp/1000.*ftmp*ftmp/(2.*cumag*NN*re)*(cuvar*zuterm + coslattmp*cvvar*zvterm)
  ; for output
    reg_Fx = where(cuvar .lt. 0, reg_Fx@_FillValue,reg_Fx)
    reg_Fy = where(cuvar .lt. 0, reg_Fy@_FillValue,reg_Fy)
  else if(opt@method .eq. "plumb")
    reg_Fx = type@level/1000./(2.*re*re*coslattmp)*xuterm
    reg_Fy = type@level/1000./(2.*re*re)*xvterm
    ; printMinMax(reg_Fx,0)
  end if
  end if

  reg_Fx!0 = "lat"
  reg_Fx&lat = lat
  reg_Fx!1 = "lon"
  reg_Fx&lon = lon
  copy_VarCoords(reg_Fx, reg_Fy)
if((call_stream[0] .eq. call_add_waf_dev) .and. is_element(bufferMode,(/"write","smart"/)))
  write_buffer(reg_Fx,id)
  write_buffer(reg_Fy,id)
end if
  ; if((bufferMode .eq. "write") .and. (call_stream[0] .eq. call_add_waf_dev))
  ;   printc("buffer: "+call_add_waf_dev,"blue")
  ;   call_stream := NewList("fifo")
  ;   bufferName = bufferPath+"buffer"+bufferCount
  ;   ; printc("buffer"+bufferCount,"yellow")
  ;   bufferCount = bufferCount+1
  ;   system("rm -rf "+bufferName+".nc")
  ;   fout = addfile(bufferName+".nc", "c")
  ;   fout->temx = reg_Fx
  ;   fout->temy = reg_Fy
  ; end if
end if

  reg_Fx@units = "m^2/s^2"
  reg_Fx@units = "m^2/s^2"  

  plot = gsn_csm_vector(tem_wks, reg_Fx, reg_Fy, res)
  overlay(plotid,plot)
end

undef("add_diff")
procedure add_diff(plotid:graphic,tp,year0,year1,range,opt)
local option,type,SST0,clim0,var0,SST1,clim1,var1,dif,nyear0,nyear1,df,S,dif_t,t,plot
begin
  nyear0 = dimsizes(year0)
  nyear1 = dimsizes(year1)
  df = nyear0+nyear1-2
  t = t_value(df)
  option = True
    option@cnLevel = t@t95
  copy_VarAtts_match(opt,option,res_plot,"")
  type := tp
    type@year = year0
  SST0 = process(type,"mean")
  clim0 = dim_avg_n_Wrap(SST0, 0)
  var0 = dim_variance_n_Wrap(SST0, 0)
    type@year = year1
  SST1 = process(type,"mean")
  clim1 = dim_avg_n_Wrap(SST1, 0)
  var1 = dim_variance_n_Wrap(SST1, 0)
  dif := clim1 - clim0
  S = sqrt(((nyear0-1)*var0+(nyear1-1)*var1)/df)
  dif_t = dif/(S*sqrt(1./nyear0+1./nyear1))
  copy_VarCoords(clim1, dif)
  copy_VarCoords(clim1, dif_t)

    ; option@cnLevels = (/10,13,16,19,22,25/)
  ; add_clim(plot,type,range,option)
  add_cn(plotid,dif,range,option)
  ; option@cnFillDotColor = "black"
  add_dots(plotid,dif_t,range,option)
end

undef("add_composite") ; FX| composite_cn
procedure add_composite(plotid:graphic,ind_year,type,range,opt)
local tem,names,levels,i,X,XH,XL,dif,method,type_clim, clim,type_ind,composite,anom,std,tval,t,usingAnom,res_test,level
begin
      print("res_test@mode")
  type_clim = type
    type_clim@range := range
  method = "anom"
  if(isatt(opt, "add_dim_to_mean"))
    method@add_dim_to_mean = opt@add_dim_to_mean
  end if
  if(isatt(opt, "detrend"))then
    method@detrend = opt@detrend
  end if
  tem = process(type_clim,method)
  ; printVarSummary(clim)
  type_ind = type
    type_ind@year := ind_year
    type_ind@range := range

  ; composite = process(type_ind,method)
  ; anom = composite-clim
  anom = dim_avg_n_Wrap(tem({ind_year},:,:), 0)

  ; copy_VarCoords(composite, anom)
  method = "stddev"
  n0 = dimsizes(ind_year)
  var0 = dim_variance_n_Wrap(tem({ind_year},:,:), 0)
  ; std = process(type_ind,method)
  var0 = where(var0 .eq. 0, 0.01, var0)
  n1 = dimsizes(type@year)
  var1 = dim_variance_n_Wrap(tem, 0)
  ; std = process(type_ind,method)
  var1 = where(var1 .eq. 0, 0.01, var1)
  tem1 = ((n0-1)*var0+(n1-1)*var1)/(n0+n1-2)
  tem2 = 1./n0+1./n1
  tem3 = var0/n0+var1/n1
  copy_VarCoords(anom, var0)
  copy_VarCoords(anom, var1)
  ; printVarSummary(anom)
  ; printVarSummary(std)
  ; tval = anom/sqrt(var0)*sqrt(n0)
  ; tval = anom/(sqrt(tem1)*sqrt(tem2))
  tval = anom/sqrt(tem3)
  copy_VarCoords(var0, tval)
  ; print("df: "+(n0+n1-2))

  t = t_value(n0+n1-2)
  ; t = t_value(n0-1)
  if(isatt(opt,"multi"))
    anom = (/anom*opt@multi/)
  end if
  usingAnom = get_res_value_keep(opt,"usingAnom",True)
  if(usingAnom)
    add_cn(plotid,anom,range,opt)
  else
    add_cn(plotid,composite,range,opt)
  end if
  res_test = get_res_value_keep(opt,"test",True)
  if(res_test)
    testMethod = get_res_value_keep(opt, "method", "t-test")
    if(testMethod .eq. "t-test")then
      res_test@mode = get_res_value_keep(opt,"mode","stippling")
      res_test@cnFillDotSizeF = 0.0025
      res_test@cnFillScaleF = 1.2
      ; res_test@stipplingColor = "black"
      exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)

      copy_VarAtts_match(opt,res_test,res_plot,exclude)
      print(res_test@mode)
      ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
      ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
      if(res_test@mode .eq. "stippling")
        if(isatt(opt,"stipplingColor"))
          res_test@stipplingColor = opt@stipplingColor
        end if
        level = get_res_value_keep(opt,"stipplingLevel",90)
        res_test@cnLevel = t@$("t"+level)$

        add_dots(plotid,tval,range,res_test)
      end if

      if(res_test@mode .eq. "contour")
        res_test@cnFillOn = False
        res_test@cnLinesOn = True
        res_test@lbLabelBarOn = False
        res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
        add_cn(plotid,tval,range,res_test)
      end if

      if(res_test@mode .eq. "hatching")then
        print("hatching")
        sigLevel = get_res_value_keep(opt,"sigLevel",90) 
        res_test = get_res_eq(opt,"hatching")
        res_test@cnFillOn = True
        res_test@cnLinesOn = False
        res_test@cnLevel = t@$("t"+sigLevel)$
        ; print(res_test)
        add_hatching(plotid,tval,range,res_test)
        ; add_hatching(plotid,tval,range,res_test)
        ; add_hatching(plotid,tval,range,res_test)
        ; add_hatching(plotid,tval,range,res_test)
        ; add_hatching(plotid,tval,range,res_test)
      end if
    end if
    if(testMethod .eq. "stddev")then
      res_test@mode = get_res_value_keep(opt,"mode","stippling")
      res_test@cnFillDotSizeF = 0.0025
      res_test@cnFillScaleF = 1.2
      ; res_test@stipplingColor = "black"
      exclude := (/"cnFillOn","Scale","gsnLeftStrings","gsnCornerStrings"/)
      printVarSummary(tem)
      copy_VarAtts_match(opt,res_test,res_plot,exclude)
      clim_std = dim_standardize_n_Wrap(tem, 0, 0)
      anom_std = dim_avg_n_Wrap(clim_std({ind_year},:,:), 0)

      ; res_test@cnLevels = (/-999,-t@t95,-t@t90,t@t90,t@t95,999/)
      ; res_test@cnLevels := (/-999,-t@t95,t@t95,999/)
      if(res_test@mode .eq. "stippling")
        std_abs = abs(anom_std)
        copy_VarCoords(anom_std, std_abs)
        if(isatt(opt,"stipplingColor"))
          res_test@stipplingColor = opt@stipplingColor
        end if
        level = get_res_value_keep(opt,"stipplingLevel",0.5)
        res_test@cnLevel = level
        add_dots(plotid,std_abs,range,res_test)
      end if

      if(res_test@mode .eq. "contour")
        level = get_res_value_keep(opt,"contourLevel",0.5)
        res_test@cnFillOn = False
        res_test@cnLinesOn = True
        res_test@lbLabelBarOn = False
        res_test@cnLevels := (/-999,-level,level,999/)
        add_cn(plotid,anom_std,range,res_test)
      end if
      if(res_test@mode .eq. "hatching")then
        sigLevel = get_res_value_keep(opt,"hatchingLevel",0.5) 
        res_test = get_res_eq(opt,"hatching")
        res_test@cnFillOn = True
        res_test@cnLinesOn = False
        res_test@cnLevels := (/-t@$("t"+sigLevel)$,t@$("t"+sigLevel)$/)
        ; print(res_test)
        add_hatching(plotid,tval,range,res_test)
        add_hatching(plotid,tval,range,res_test)
        add_hatching(plotid,tval,range,res_test)
        add_hatching(plotid,tval,range,res_test)
        add_hatching(plotid,tval,range,res_test)
      end if
    end if
  end if
end

undef("add_composite_vc") ; FX| composite_cn
procedure add_composite_vc(plotid:graphic,ind_year,type,range,opt)
local tem,type_x,type_z,method,add_dim_to_mean,type_h,h_anom,names,levels,i,X,XH,XL,dif
begin
  type_x = type
    type_x@range := range
  type_z = type
    type_z@range := range
  method = "clim"
  if(isatt(opt,"add_dim_to_mean"))
    add_dim_to_mean = opt@add_dim_to_mean
    if(is_element(add_dim_to_mean,(/"lon","longitude"/)))
      type_x = "v"
      type_z = "vv"
    elseif(is_element(add_dim_to_mean,(/"lat","latitude"/)))
      type_x = "u"
      type_z = "vv"
    end if
    method@add_dim_to_mean = add_dim_to_mean
  end if
  if(type .eq. "wvf")
    type_x = "qu"
    type_z = "qv"
  end if

  if(type .eq. "waf")then
    type_h = type
    type_h@range := range
    type_h = "h"
    method = "anom"
    if(isatt(opt, "add_dim_to_mean"))
      method@add_dim_to_mean = opt@add_dim_to_mean
    end if
    if(isatt(opt, "detrend"))then
      method@detrend = opt@detrend
    end if
    tem = process(type_h,method)
    ; composite = process(type_ind,method)
    ; anom = composite-clim
    h_anom = dim_avg_n_Wrap(tem({ind_year},:,:), 0)
    type_h = "t"
    method := "clim"
    t_clim = process(type_h,method)
    type_h = "u"
    u_clim = process(type_h,method)
    type_h = "v"
    v_clim = process(type_h,method)
    waf = waf_2D(h_anom,t_clim,u_clim,v_clim,type_h@level);返回值为一个列表，用中括号获取列表元素
    fx = waf[0]
    fy = waf[1]
    add_vc_dev(plotid,fx,fy,range,opt)
    return
  end if

  x_clim = process(type_x,method)
  z_clim = process(type_z,method)

  type_x@year := ind_year
  type_z@year := ind_year
  x_comp = process(type_x,method)
  z_comp = process(type_z,method)

  x_anom = x_comp-x_clim
  z_anom = z_comp-z_clim

  copy_VarCoords(x_comp, x_anom)
  copy_VarCoords(z_comp, z_anom)

  method = "stddev"
  x_std = process(type_x,method)
  z_std = process(type_z,method)

  x_std = where(x_std .eq. 0, 0.01, x_std)
  z_std = where(z_std .eq. 0, 0.01, z_std)

  copy_VarCoords(x_anom, x_std)
  copy_VarCoords(z_anom, z_std)



  x_tval = abs(x_anom/x_std*sqrt(dimsizes(ind_year)))
  z_tval = abs(z_anom/z_std*sqrt(dimsizes(ind_year)))
  tval = where(x_tval .ge. z_tval, x_tval, z_tval)

  copy_VarCoords(x_comp, tval)

  t = t_value(dimsizes(ind_year)-1)
  if(isatt(opt,"multi"))
    z_anom = (/z_anom*opt@multi/)
  end if
  add_vc_dev(plotid,x_anom,z_anom,range,opt)
  ; add_cn(plotid,anom,range,opt)
end

undef("add_lc_labels")
procedure add_lc_labels(plotid,range,res)
local lat_values, nlat, lat1_ndc, lat2_ndc, lon1_ndc, lon2_ndc,slope,txres, \
lon_values, PI, RAD_TO_DEG, dum_lft, dum_rgt, dum_bot,minlat,maxlat,minlon,maxlon,lat_spacing,lon_spacing
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  minlat = range(0)
  maxlat = range(1)
  minlon = range(2)
  maxlon = range(3)
  lat_spacing = get_res_value_keep(res, "lat_spacing", 10)
  lon_spacing = get_res_value_keep(res, "lon_spacing", 10)
  PI         = 3.14159
  RAD_TO_DEG = 180./PI

;---Pick some "nice" values for the latitude labels.
  lat_values = ispan(toint(minlat),toint(maxlat),lat_spacing) * 1.
  nlat       = dimsizes(lat_values)
;
; We need to get the slope of the left and right min/max longitude lines.
; Use NDC coordinates to do this.
;
  lat1_ndc = new(1,float)
  lon1_ndc = new(1,float)
  lat2_ndc = new(1,float)
  lon2_ndc = new(1,float)
  datatondc(plotid,minlon,lat_values(0),lon1_ndc,lat1_ndc)
  datatondc(plotid,minlon,lat_values(nlat-1),lon2_ndc,lat2_ndc)
  if(lon2_ndc.eq.lon1_ndc) then
      print("add_lc_labels: error: not enough valid latitude values to generate labels")
      print("    You may need to decrease the lat_spacing")
      exit
  end if
  slope_lft = (lat2_ndc-lat1_ndc)/(lon2_ndc-lon1_ndc)

  datatondc(plotid,maxlon,lat_values(0),lon1_ndc,lat1_ndc)
  datatondc(plotid,maxlon,lat_values(nlat-1),lon2_ndc,lat2_ndc)
  if(lat2_ndc.eq.lat1_ndc) then
      print("add_lc_labels: error: not enough valid longitude values to generate labels")
      print("    You may need to decrease the lon_spacing")
      exit
  end if
  slope_rgt = (lat2_ndc-lat1_ndc)/(lon2_ndc-lon1_ndc)

;---Set some text resources
  txres               = True
  txres@txFontHeightF = get_res_value_keep(res, "txFontHeightF", 0.01)
  txres@txPosXF       = 0.1
;
; Loop through lat values, and attach labels to the left and
; right edges of the masked LC plot.  The labels will be 
; rotated to fit the line better.
;
  dum_lft = new(nlat,graphic)    ; Dummy array to hold attached strings.
  dum_rgt = new(nlat,graphic)    ; Dummy array to hold attached strings.
  do n=0,nlat-1
; Add extra white space to labels.
    lat_label_rgt = "          "  + lat_values(n) + ""

;---Check if North, South, or Zero
    if(lat_values(n).lt.0) then
      lat_label_lft = lat_values(n) + "S          "
      lat_label_rgt = lat_label_rgt + "S"
    end if
    if(lat_values(n).gt.0) then
      lat_label_lft = lat_values(n) + "N          "
      lat_label_rgt = lat_label_rgt + "N"
    end if
    if(lat_values(n).eq.0) then
      lat_label_lft = lat_values(n) + "           "
    end if

;---Left label
    txres@txAngleF = RAD_TO_DEG * atan(slope_lft) - 90
  if(isatt(res, "txAngleF"))then
    txres@txAngleF = res@txAngleF
  end if
    dum_lft(n) = gsn_add_text(tem_wks,plotid,lat_label_lft,minlon,lat_values(n),txres)

;---Right label
    txres@txAngleF = RAD_TO_DEG * atan(slope_rgt) + 90
  if(isatt(res, "txAngleF"))then
    txres@txAngleF = res@txAngleF
  end if
    dum_rgt(n) = gsn_add_text(tem_wks,plotid,lat_label_rgt,maxlon,lat_values(n),txres)
  end do

;----------------------------------------------------------------------
; Now do longitude labels. These are harder because we're not
; adding them to a straight line.
;
; Loop through lon values, and attach labels to the bottom edge of the
; masked LC plot.
;
  delete(txres@txPosXF)
  txres@txPosYF = -5.0

;---Pick some "nice" values for the longitude labels.
  lon_values = ispan(toint(minlon+10),toint(maxlon-10),lon_spacing) * 1.
  nlon       = dimsizes(lon_values)

  dum_bot = new(nlon,graphic)    ; Dummy array to hold attached strings.

  do n=0,nlon-1
;
; For each longitude label, we need to figure out how much to rotate
; it, so get the approximate slope at that point.
;
    datatondc(plotid,lon_values(n)-0.25,minlat,lon1_ndc,lat1_ndc)
    datatondc(plotid,lon_values(n)+0.25,minlat,lon2_ndc,lat2_ndc)
    slope_bot = (lat1_ndc-lat2_ndc)/(lon1_ndc-lon2_ndc)
    txres@txAngleF  = atan(slope_bot) * RAD_TO_DEG
;
; Create longitude label. Add extra carriage returns to
; move label away from plot.
;
;---Check if East, West, or Zero
    lon_label_bot = "  ~C~  ~C~" + abs(lon_values(n))
    if(lon_values(n).lt.0) then
      lon_label_bot = lon_label_bot + "W"
    end if
    if(lon_values(n).gt.0) then
      lon_label_bot = lon_label_bot + "E"
    end if

;---Attach to plotid.
    dum_bot(n) = gsn_add_text(tem_wks,plotid,lon_label_bot,lon_values(n),minlat,txres)
  end do
end

undef("plt_cn"); FX| plt_cn
function plt_cn(wks,var,ranges,opt)
local wks,plot,clr,res,i,x,simple_mode
begin
; 判断var是否为列表类型，若为单变量列表或者普通变量，则只需要画填色
; 目的：同时兼容只画简单图与多变量叠图的需求
if(typeof(var) .eq. "list")
  x = var[0]
  list_size = ListCount(var)
  simple_mode = (list_size .eq. 1)
else
  x = var
  simple_mode = True
end if
; cmap = read_colormap_file("33colors.rgb")
; gsn_define_colormap(wks,cmap)
; opt@polar  = get_res_value_keep(opt,"polar",False)
clr = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
; clr@clr        = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
; clr@clr0        = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0B525","#A57E1E"/)
; clr@clr1        = (/"#555aa7","#7c7aba","#bab4d8","#ebe9f4","#FFFFFF","#fde9eb","#f8b1b5","#f38380","#f0534e"/)
; x@color = get_res_value_keep(opt,color")
res = True
  res@tmXTOn = False
  res@tmYROn = False
  res@vpHeightF = 0.6
  res@vpWidthF = 0.82
  res@vpXF = 0.12
  res@vpYF = 0.9
  res@cnFillOn = True
  ; res@cnFillDrawOrder = "predraw"
  res@cnInfoLabelOn = False
  res@mpShapeMode        = "FreeAspect"
  res@cnLevelSelectionMode = "ExplicitLevels"
  res@tmXBMajorLengthF = 0.01
  res@tmXBLabelDeltaF = -0.4
  res@tmYLLabelDeltaF = -0.4
  res@tmYLLabelFontHeightF = 0.03
  res@tmXBLabelFontHeightF = 0.03
  res@tmYLLabelsOn = True
  res@tmXBLabelsOn = True
  res@tiYAxisString = ""
  res@tiXAxisString = ""
  res@mpMinLatF           = ranges(0)
  res@mpMaxLatF           = ranges(1)
  res@mpCenterLonF        = ranges(2)/2+ranges(3)/2
  res@mpMinLonF = ranges(2)
  res@mpMaxLonF = ranges(3)
  res@gsnAddCyclic = False
  res@tmBorderThicknessF = 5
  ;干掉愚蠢的gsnString，后面自己写
  res@gsnLeftString = ""
  res@gsnRightString = ""
  res@gsnLeftStringFontHeightF = 0.035
  res@tmXBMinorOn = False
  res@tmXBLabelStride = 2
  res@tmYLLabelStride = 2
  res@tmYLMinorOn = False
  res@cnLinesOn = False
  res@cnLineLabelsOn = False
  res@gsnContourNegLineDashPattern = 1
  res@cnLevels = (/-4,-3,-2,-1,1,2,3,4/)
  res@Scale = 1
  res@cnFillColors = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0B525","#A57E1E"/)
  ; res_plot = (/"am","app","ca","cn","ct","dc","err","gs","gsn","lb","lg","mp","pm","pr","sf","st","tf","ti","tm","tr","tx","vc","vf","vp","wk","ws","xy"/)
  ; res_plot = (/"am","cn","gs","gsn","lb","lg","mp","pm","pr","sf","st","tf","ti","tm","tr","tx","vc","vf","vp","wk","ws","xy","Scale"/)
  exclude = (/"time","_FillValue","trend_scale"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  copy_VarAtts_match(x,res,res_plot,exclude)
  ; copy_VarAtts_eq(opt,res,res_plot)
  ; copy_VarAtts_eq(x,res,res_plot)
  ; printVarSummary(res)
  ; res = get_res_eq(opt,res_plot)
  ; copy_VarAtts(opt,res)
  ; printVarSummary(x)
  ; copy_VarAtts_except(x,res,except)
  if(isatt(res,"lbLabelBarOn") .and. res@lbLabelBarOn)
    res@lbLabelAutoStride = False
    setLabelbar(res)
    if(isatt(res,"lbTitleString"))
      setLabelbarTitle(res,res@lbTitleString)
    end if
    ; if(isatt(opt,"lbLabelStride"))
    ;   res@lbLabelStride = opt@lbLabelStride
    ; end if
    if(is_element(res@lbOrientation,(/"Horizontal","horizontal"/)))
      res@pmLabelBarOrthogonalPosF = get_res_value_keep(opt,"pmLabelBarOrthogonalPosF",0.15)
      res@pmLabelBarParallelPosF   = get_res_value_keep(opt,"pmLabelBarParallelPosF",0.5)
      res@pmLabelBarWidthF         = get_res_value_keep(opt,"pmLabelBarWidthF",res@vpWidthF)
      res@pmLabelBarHeightF        = get_res_value_keep(opt,"pmLabelBarHeightF",0.15)
    else
      res@pmLabelBarWidthF         = get_res_value_keep(opt,"pmLabelBarWidthF",0.15)
      res@pmLabelBarHeightF        = get_res_value_keep(opt,"pmLabelBarHeightF",res@vpHeightF+0.15)
      res@pmLabelBarOrthogonalPosF = get_res_value_keep(opt,"pmLabelBarOrthogonalPosF",0.05)
      res@pmLabelBarParallelPosF   = get_res_value_keep(opt,"pmLabelBarParallelPosF",0.45)
    end if
  end if

  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF
  res@cnLevels            := res@cnLevels*res@Scale
  delete(res@Scale)

  if(get_res_value_keep(opt,"reverseColors",False))
    res@cnFillColors =  res@cnFillColors(::-1)
  end if
  if(typeof(res@cnLevels) .eq. "float")
    format = get_res_value_keep(opt,"lbLabelFormat","%0.2f")
    res@lbLabelStrings = sprintf(format, res@cnLevels)
  end if

  vardim = getvardims(x)
  ; if(is_element("lat",vardim))
  ;   set_XBTick(res,"lat")
  ; else if (is_element("lon",vardim)) then 
  ;   set_XBTick(res,"lon")
  ; end if
  ; end if

  ; if(get_res_value_keep(opt,"debug",False))
  ;   res@name = "plot_res"
  ;   isOverWrite = get_res_value_keep(opt,"overWrite",True)
  ;   md_print(res,isOverWrite)
  ; end if
    ; res@lbBoxEndCapStyle = "TriangleBothEnds"

  plot = gsn_csm_contour_map(wks, x, res)


  if(isatt(opt,"gsnCornerString"))
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if


if(.not. simple_mode)
do i = 1,list_size-1,1
  y := var[i]
  setDefaultAtt(y,"mode","contour")
  ; y@mode = get_res_value_keep(y,"mode","contour");contour or stippling

  ; copy_VarAtts(y,reso)
  ; reso = get_res_eq(y,"cn")
  reso := True
  reso@cnLevelSelectionMode = "ExplicitLevels"
  reso@gsnDraw = False
  reso@gsnFrame = False
  reso@cnLevels = (/-5,-4,-3,-2,-1,1,2,3,4,5/)
  reso@Scale = 1.

  reso@cnLineLabelsOn = False
  reso@gsnLeftString = ""
  reso@gsnRightString = ""
  ; printVarSummary(reso)
  exclude := (/"time","_FillValue"/)
  ; printVarSummary(reso)
  copy_VarAtts_match(y,reso,res_plot,exclude)
  ; printVarSummary(reso)
  ; copy_VarAtts_eq(y,reso,res_plot)
  reso@cnLevels := reso@cnLevels*reso@Scale
  ; print(reso@Scale)
  delete(reso@Scale)
  ; printVarSummary(reso)
  if(y@mode .eq. "contour")
    reso@cnLinesOn = True
    reso@cnMonoLineColor = True
    reso@cnInfoLabelOn = False
    if(isatt(y,"drawOrder"))
      reso@cnLineDrawOrder = y@drawOrder
    end if
    reso@cnLineThicknessF = get_res_value_keep(y,"cnLineThicknessF", 5)
    if(isatt(y,"cnLineColors"))
      reso@cnMonoLineColor = False
      reso@cnLineColors = y@cnLineColors
    end if
    if(isatt(y,"cnLineThicknesses"))
      reso@cnLineThicknesses = y@cnLineThicknesses
      reso@cnMonoLineThickness = False
    end if
  elseif(y@mode .eq. "shading")
    reso@cnLinesOn = False
    reso@cnFillOn = True
    reso@cnInfoLabelOn = False
    if(isatt(y,"drawOrder"))
      reso@cnFillDrawOrder = y@drawOrder
    end if
  elseif(y@mode .eq. "stippling")
    stipplingColor = get_res_value_keep(y,"stipplingColor","white")
    reso@cnFillOn = True
    reso@cnLinesOn = False
    reso@lbLabelBarOn = False
    reso@cnInfoLabelOn = False
    reso@cnMonoFillPattern = False
    reso@cnFillPatterns = get_res_value_keep(y,"cnFillPatterns",(/17,17,-1,17,17/))
    reso@cnFillColors   = get_res_value_keep(y,"cnFillColors",(/stipplingColor,stipplingColor,"gray",stipplingColor,stipplingColor/))
    reso@cnLinesOn      = False
    if(isatt(y,"drawOrder"))
      reso@cnFillDrawOrder = y@drawOrder
    end if
    reso@cnFillScaleF = get_res_value_keep(y,"cnFillScaleF",2.0)
    reso@cnFillDotSizeF = get_res_value_keep(y,"cnFillDotSizeF",0.001)
    ; printVarSummary(reso)
  end if
  plot_o = gsn_csm_contour(wks, y, reso)
  overlay(plot, plot_o)
end do
end if

if(get_res_value_keep(opt,"dots",False))
  resl = True
  resl@gsLineColor      = get_res_value_keep(opt,"dotsColor","firebrick1")
  resl@gsLineThicknessF = get_res_value_keep(opt,"dotsLineThicknessF",15.0)
  ; resl@tfPolyDrawOrder = "PostDraw"
  ; resl@xyCurveDrawOrder = "PostDraw"
  str = unique_string("polyline")
  plot@$str$            = gsn_add_polyline(wks, plot,opt@dotslon,opt@dotslat,resl)
  if(get_res_value_keep(opt,"dots1",False))
    str1 = unique_string("polyline") 
    plot@$str1$ = gsn_add_polyline(wks, plot,opt@dotslon1,opt@dotslat1,resl)
  end if
  if(get_res_value_keep(opt,"dots2",False))
    str2 = unique_string("polyline") 
    plot@$str2$ = gsn_add_polyline(wks, plot,opt@dotslon2,opt@dotslat2,resl)
  end if
end if
return(plot)
end

undef("plt_cn_ver"); FX| plt_cn_ver
function plt_cn_ver(wks[1]:graphic,var,ranges,opt)
local x,simple_mode,i
begin
; 判断var是否为列表类型，若为单变量列表或者普通变量，则只需要画填色
; 目的：同时兼容只画简单图与多变量叠图的需求
if(typeof(var) .eq. "list")
  x = var[0]
  list_size = ListCount(var)
  simple_mode = (list_size .eq. 1)
else
  x = var
  simple_mode = True
end if

; cmap = read_colormap_file("33colors.rgb")
; gsn_define_colormap(wks,cmap)
; opt@polar  = get_res_value_keep(opt,"polar",False)
clr = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
; clr@clr        = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
; clr@clr0        = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0B525","#A57E1E"/)
; clr@clr1        = (/"#555aa7","#7c7aba","#bab4d8","#ebe9f4","#FFFFFF","#fde9eb","#f8b1b5","#f38380","#f0534e"/)



; if(isatt(y,"cnLineColors"))
;   if(dimsizes(y@cnLineColors) .eq. 1)
;     y@cnLineColors                = clr@$y@cnLineColors$
;   end if
;   if(get_res_value_keep(opt,"yReverseColors",False))
;   y@cnLineColors =  y@cnLineColors(::-1)
;   end if
; end if


cnLevels   = (/-8,-7,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,7,8/)
; x@cnLevels = get_res_value_keep(x,"cnLevels",(/-4,-3,-2,-1,1,2,3,4/))
; y@cnLevels = get_res_value_keep(y,"cnLevels",cnLevels)
; z@cnLevels = get_res_value_keep(z,"cnLevels",cnLevels)
; x@Scale    = get_res_value_keep(x,"Scale",1)
; y@Scale    = get_res_value_keep(y,"Scale",1)
; z@Scale    = get_res_value_keep(z,"Scale",1)
; default
res = True
  res@tmXTOn = False
  res@tmYROn = False
  res@vpHeightF = 0.6
  res@vpWidthF = 0.82
  res@vpXF = 0.12
  res@vpYF = 0.9
  res@cnFillOn = True
  res@cnFillDrawOrder = "predraw"
  res@gsnPresHgtHeightLabelOn = False
  res@cnInfoLabelOn = False
  res@cnLevelSelectionMode = "ExplicitLevels"
  res@tmXBMajorLengthF = 0.01
  res@tmXBLabelDeltaF = -0.4
  res@tmYLLabelDeltaF = -0.4
  res@tmYLLabelFontHeightF = 0.03
  res@tmXBLabelFontHeightF = 0.03
  res@tmYLLabelsOn = True
  res@tmXBLabelsOn = True
  res@tiYAxisString = ""
  res@tiXAxisString = ""
  res@tmBorderThicknessF = 5

  ;干掉愚蠢的gsnString，后面自己写
  res@gsnLeftString = ""
  res@gsnRightString = ""
  res@gsnLeftStringFontHeightF = 0.035
  res@gsnLeftStringOrthogonalPosF = 0.06
  res@tmYLTickSpacingF = 10
  res@tmXBTickSpacingF = 10
  res@tmXBMinorOn = False
  res@tmXBLabelStride = 2
  res@tmYLLabelStride = 2
  res@tmYLMinorOn = False
  res@cnLinesOn = False
  res@cnLineLabelsOn = False
  res@gsnContourNegLineDashPattern = 1
  res@cnLevels = (/-4,-3,-2,-1,1,2,3,4/)
  res@Scale = 1
  res@trXMaxF = ranges(1)
  res@trXMinF = ranges(0)
  ; res@tmXBMode = "Explicit"
  res@cnFillColors = (/"#407933","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0B525","#A57E1E"/)
  copy_VarAtts_eq(opt,res,res_plot)
  copy_VarAtts_eq(x,res,res_plot)
  ; copy_VarAtts(opt,res)
  ; copy_VarAtts_except(x,res,"_FillValue")
  if(isatt(res,"lbLabelBarOn") .and. res@lbLabelBarOn)
    res@lbLabelAutoStride = False
    setLabelbar(res)
    if(isatt(res,"lbTitleString"))
      setLabelbarTitle(res,res@lbTitleString)
    end if
    ; if(isatt(opt,"lbLabelStride"))
    ;   res@lbLabelStride = opt@lbLabelStride
    ; end if
    if(is_element(res@lbOrientation,(/"Horizontal","horizontal"/)))
      res@pmLabelBarOrthogonalPosF = get_res_value_keep(opt,"pmLabelBarOrthogonalPosF",0.15)
      res@pmLabelBarParallelPosF   = get_res_value_keep(opt,"pmLabelBarParallelPosF",0.5)
      res@pmLabelBarWidthF         = get_res_value_keep(opt,"pmLabelBarWidthF",res@vpWidthF)
      res@pmLabelBarHeightF        = get_res_value_keep(opt,"pmLabelBarHeightF",0.15)
    else
      res@pmLabelBarWidthF         = get_res_value_keep(opt,"pmLabelBarWidthF",0.15)
      res@pmLabelBarHeightF        = get_res_value_keep(opt,"pmLabelBarHeightF",res@vpHeightF+0.15)
      res@pmLabelBarOrthogonalPosF = get_res_value_keep(opt,"pmLabelBarOrthogonalPosF",0.05)
      res@pmLabelBarParallelPosF   = get_res_value_keep(opt,"pmLabelBarParallelPosF",0.45)
    end if
  end if

  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF
  res@cnLevels            = res@cnLevels*res@Scale
  delete(res@Scale)

  if(get_res_value_keep(opt,"reverseColors",False))
    res@cnFillColors =  res@cnFillColors(::-1)
  end if
  if(typeof(res@cnLevels) .eq. "float")
    format = get_res_value_keep(opt,"lbLabelFormat","%0.2f")
    res@lbLabelStrings = sprintf(format, res@cnLevels)
  end if

  vardim = getvardims(x)
  ; if(is_element("lat",vardim))
  ;   set_XBTick(res,"lat")
  ; else if (is_element("lon",vardim)) then 
  ;   set_XBTick(res,"lon")
  ; end if
  ; end if

  ; if(get_res_value_keep(opt,"debug",False))
  ;   res@name = "plot_res"
  ;   isOverWrite = get_res_value_keep(opt,"overWrite",True)
  ;   md_print(res,isOverWrite)
  ; end if
  ; printVarSummary(res)
  plot = gsn_csm_pres_hgt(wks, x, res)

  ; 手动接管gsnLeftString和gsnRightString
  ; if(isatt(opt,"gsnLeftString"))
  ;   res_text = get_res_eq(opt,"gsnLeft")
  ;   add_LeftString(plot,opt@gsnLeftString,res_text)
  ; end if

  ; if(isatt(opt,"gsnRightString"))
  ;   res_text = get_res_eq(opt,"gsnRight")
  ;   add_RightString(plot,opt@gsnRightString,res_text)
  ; end if

  if(isatt(opt,"gsnCornerString"))
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeightF = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    add_CornerString(plot,corner)
  end if



if(.not. simple_mode)
do i = 1,list_size-1,1
  y := var[i]
  setDefaultAtt(y,"mode","contour")
  ; y@mode = get_res_value_keep(y,"mode","contour");contour or stippling

  ; copy_VarAtts(y,reso)
  ; reso = get_res_eq(y,"cn")
  reso := True
  reso@cnLevelSelectionMode = "ExplicitLevels"
  reso@gsnDraw = False
  reso@gsnFrame = False
  reso@cnLevels = (/-5,-4,-3,-2,-1,1,2,3,4,5/)
  reso@Scale = 1.

  reso@cnLineLabelsOn = False
  reso@gsnLeftString = ""
  reso@gsnRightString = ""
  ; printVarSummary(reso)
  exclude = (/"time","_FillValue"/)
  copy_VarAtts_match(y,reso,res_plot,exclude)
  ; copy_VarAtts_eq(y,reso,res_plot)
  reso@cnLevels := reso@cnLevels*reso@Scale
  delete(reso@Scale)

  if(y@mode .eq. "contour")
    reso@cnLinesOn = True
    reso@cnMonoLineColor = True
    reso@cnInfoLabelOn = False
    reso@cnLineColor = get_res_value_keep(y,"cnLineColor","black") 
    if(isatt(y,"drawOrder"))
      reso@cnLineDrawOrder = y@drawOrder
    end if
    reso@cnLineThicknessF = get_res_value_keep(y,"cnLineThicknessF", 5)
    if(isatt(y,"cnLineColors"))
      reso@cnMonoLineColor = False
      reso@cnLineColors = y@cnLineColors
    end if
    if(isatt(y,"cnLineThicknesses"))
      reso@cnLineThicknesses = y@cnLineThicknesses
      reso@cnMonoLineThickness = False
    end if
  else if(y@mode .eq. "stippling")
    stipplingColor = get_res_value_keep(y,"stipplingColor","white")
    reso@cnFillOn = True
    reso@cnLinesOn = False
    reso@lbLabelBarOn = False
    reso@cnInfoLabelOn = False
    reso@cnMonoFillPattern = False
    reso@cnFillPatterns = get_res_value_keep(y,"cnFillPatterns",(/17,17,-1,17,17/))
    reso@cnFillColors   = get_res_value_keep(y,"cnFillColors",(/stipplingColor,stipplingColor,"gray",stipplingColor,stipplingColor/))
    reso@cnLinesOn      = False
    if(isatt(y,"drawOrder"))
      reso@cnFillDrawOrder = y@drawOrder
    end if
    reso@cnFillScaleF = get_res_value_keep(y,"cnFillScaleF",2.0)
    reso@cnFillDotSizeF = get_res_value_keep(y,"cnFillDotSizeF",0.001)
  end if
  end if
  plot_o = gsn_csm_contour(wks, y, reso)
  overlay(plot, plot_o)
end do
end if

if(get_res_value_keep(opt,"dots",False))
  resl = True
  resl@gsLineColor      = get_res_value_keep(opt,"dotsColor","firebrick1")
  resl@gsLineThicknessF = get_res_value_keep(opt,"dotsLineThicknessF",15.0)
  ; resl@tfPolyDrawOrder = "PostDraw"
  ; resl@xyCurveDrawOrder = "PostDraw"
  str = unique_string("polyline")
  plot@$str$            = gsn_add_polyline(wks, plot,opt@dotslon,opt@dotslat,resl)
  if(get_res_value_keep(opt,"dots1",False))
    str1 = unique_string("polyline") 
    plot@$str1$ = gsn_add_polyline(wks, plot,opt@dotslon1,opt@dotslat1,resl)
  end if
  if(get_res_value_keep(opt,"dots2",False))
    str2 = unique_string("polyline") 
    plot@$str2$ = gsn_add_polyline(wks, plot,opt@dotslon2,opt@dotslat2,resl)
  end if
end if
  if(isatt(wks,"quickPlot") .and. wks@quickPlot)
    ; if((.not. res@gsnDraw) .and. (.not. res@gsnFrame))
    ;   draw(plot)
    ;   frame(wks)
    ; end if
    system("open -a /System/Applications/Preview.app "+readpath(1)+"plot_tem/tem.png")
    system("open -a /Applications/Visual\ Studio\ Code.app")
  end if
return(plot)
end

undef("add_topo") ; FX| add_topo
procedure add_topo(plotid:graphic,range,altitude,opt)
local plot,tem_wks,topo,topof,res_t
  begin
  option = opt
  tem_wks = NhlGetParentWorkstation(plotid)
  ; pres       = (/1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100/)
  ; pres       = pres(::-1)
  ; pres@units = "hecto-pascals"
  f          = addfile(localpath(2)+"ETOPO1.nc","r")
  topo       = f->z({range(0):range(1)},{range(2):range(3)})
  topof = smth9_Wrap(topo*1.0,0.5,0.5,False)
  copy_VarCoords(topo,topof)
  ; topof = topo
  ; if(opt@Orientation .eq. "meridional")
  ;   topo := dim_avg_n_Wrap(topo,1)
  ; else
  ;   topo := dim_avg_n_Wrap(topo,0)
  ; end if
  ; topo = (/1013.25*(1-topo*0.0065/288.15)^5.25145/)
  ; topo = where(topo .gt. 1000, 1000, topo)
  res_t = True
  option@mode = get_res_value_keep(opt,"mode","shading")
clr = (/"transparent","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)

  if(option@mode .eq. "shading")
    res_t@cnFillOn = True
    ; res_t@cnFillColors = (/-1,1,1/)
    res_t@cnFillColors = (/"transparent",get_res_value_keep(opt,"cnFillColor", "black")/)
    res_t@cnLinesOn = False
    res_t@lbLabelBarOn = False 
    res_t@cnFillOpacityF = get_res_value_keep(opt, "cnFillOpacityF", 1.0)
  elseif (option@mode .eq. "contour")
    res_t@cnFillOn = False
    res_t@cnLinesOn = True
    res_t@cnLineColor = get_res_value_keep(opt,"cnLineColor", "black")
    res_t@cnLineThicknessF = get_res_value_keep(opt,"cnLineThicknessF",2)
  end if
  ; res_t@lbLabelBarOn = False
  res_t@cnLevelSelectionMode = "ExplicitLevels"
  res_t@lbLabelFontHeightF = 0.01
  res_t@pmLabelBarOrthogonalPosF = 0.1
  ; res_t@cnLevels = (/altitude,10000/)*1.0
  res_t@cnLevels = altitude
  res_t@cnInfoLabelOn = False
  res_t@cnLineLabelsOn = False

  ; res_t@tmYRMode = "Automatic"
  ; set_pres_hgt_axes(pres,res_t,False)
  ; res_t@trYReverse            = True
  ; res_t@trYMaxF               = 1000
  ; res_t@trYMinF               = 100
  ; res_t@trYLog                = True
  ; res_t@gsnYRefLine           = 1000
  res_t@gsnFrame              = False
  res_t@gsnDraw               = False
  ; res_t@gsnAboveYRefLineColor = "black"
  ; res_t@gsnBelowYRefLineColor = "black"
  ; res_t@xyCurveDrawOrder      = "PostDraw"
  ; res_t@tiYAxisString         = ""
  ; str = unique_string("topo")
  ; if(opt@Orientation .eq. "meridional")
  ; plot = gsn_csm_xy(wks,topo&lat,topo,res_t)
  ; else
  ; plot = gsn_csm_xy(wks,topo&lon,topo,res_t)
  ; end if
  res_t@cnFillDrawOrder = get_res_value_keep(opt, "cnFillDrawOrder", "PostDraw")
  res_t@gsnLeftString = ""
  plot = gsn_csm_contour(tem_wks,topof,res_t)
  overlay(plotid,plot)
end

undef("add_topo_dev") ; FX| add_topo
procedure add_topo_dev(plotid:graphic,range,altitude,opt)
local plot,tem_wks,topo,topof,res_t,option,clr
  begin
  option = opt
  tem_wks = NhlGetParentWorkstation(plotid(0))
  f          = addfile(localpath(2)+"ETOPO1.nc","r")
  topo       = f->z({range(0):range(1)},{range(2):range(3)})
  topof = smth9_Wrap(topo*1.0,0.5,0.5,False)
  copy_VarCoords(topo,topof)
  res_t = True
  option@mode = get_res_value_keep(opt,"mode","shading")
clr = (/"transparent","#6CB650","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  res_t@cnFillOn = get_res_value_keep(opt,"cnFillOn", True)
  res_t@cnFillColors = (/"transparent",get_res_value_keep(opt,"cnFillColor", "black")/)
  res_t@cnLinesOn = get_res_value_keep(opt,"cnLinesOn", True)
  res_t@lbLabelBarOn = False 
  res_t@cnLineColor = get_res_value_keep(opt,"cnLineColor", "black")
  res_t@cnLineThicknessF = get_res_value_keep(opt,"cnLineThicknessF",2)
  res_t@cnLevelSelectionMode = "ExplicitLevels"
  res_t@lbLabelFontHeightF = 0.01
  res_t@pmLabelBarOrthogonalPosF = 0.1
  ; res_t@cnLevels = (/altitude,10000/)*1.0
  res_t@cnLevels = altitude
  res_t@cnInfoLabelOn = False
  res_t@cnLineLabelsOn = False
  res_t@gsnFrame              = False
  res_t@gsnDraw               = False
  res_t@cnFillDrawOrder = "PostDraw"
  res_t@gsnLeftString = ""
  plot := newPlots(dimsizes(plotid))
  do i = 0, dimsizes(plotid)-1
    plot(i) = gsn_csm_contour(tem_wks,topof,res_t)
    overlay(plotid(i),plot(i))
  end do
end

undef("add_topo_ver") ; FX| add_topo_ver
function add_topo_ver(plotid:graphic,pres,opt)
;必须得是function，因为必须要把plot传回去，不然填色叠不上
  begin
  range = opt@range
  tmp_wks = NhlGetParentWorkstation(plotid)
  ; pres       = (/1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100/)
  ; pres       = pres(::-1)
  pres@units = "hecto-pascals"
  f          = addfile(localpath(2)+"ETOPO1.nc","r")
  topo       = f->z({range(0):range(1)},{range(2):range(3)})
  topo := dim_avg_n_Wrap(topo,opt@dim_to_avg)
  topo = (/1013.25*(1-topo*0.0065/288.15)^5.25145/)
  topo = where(topo .gt. 1000, 1000, topo)
  res_t = True
  res_t@tmYRMode = "Automatic"
  set_pres_hgt_axes(pres,res_t,False)
  res_t@trYReverse            = True
  res_t@trYMaxF               = 1000
  res_t@trYMinF               = 100
  res_t@trYLog                = True
  res_t@gsnYRefLine           = 999.9
  res_t@gsnFrame              = False
  res_t@gsnDraw               = False
  res_t@gsnAboveYRefLineColor = "black"
  res_t@gsnBelowYRefLineColor = "black"
  res_t@xyCurveDrawOrder      = "postdraw"
  res_t@tfPolyDrawOrder = "postdraw"
  res_t@tiYAxisString         = ""
  dimName = getvardims(topo)
  plot = gsn_csm_xy(tmp_wks,topo&$dimName$,topo,res_t)
  overlay(plotid,plot)
  return(plot)
end

undef("plot_topo")
function plot_topo (wks,range,opt)
local pres,topo,dimName,res,method,plot
begin
  method = get_res_value_keep(opt,"method","mean")
  ; range = opt@range
  pres       = (/1000,975,950,925,900,875,850,825,800,775,750,700,650,600,550,500,450,400,350,300,250,225,200,175,150,125,100/)
  pres@units = "hecto-pascals"
  ; pres       = pres(::-1)
  topo = read_topo(localpath(2)+"ETOPO1.nc","z",range)
  if( .not. isatt(opt, "dim_to_mean"))then
    print("att 'dim_to_mean' is not found")
    return 0
  end if
  if(method .eq. "min")then
    topo := dim_min_n_Wrap(topo,opt@dim_to_mean)
  elseif(method .eq. "max")then
    topo := dim_max_n_Wrap(topo,opt@dim_to_mean)
  else
    topo := dim_avg_n_Wrap(topo,opt@dim_to_mean)
  end if
  if(typeof(topo) .eq. "integer")
    topo := int2flt(topo)
  end if
  topo = (/1013.25*(1-topo*0.0065/288.15)^5.25145/)
  topo = where(topo .gt. 1000, 1000, topo)
  dimName = getvardims(topo)
  res = True
  res@tmYRMode = "Automatic"
  set_pres_hgt_axes(pres,res,False)
  res@trYReverse            = True
  res@trYMaxF               = where(dimsizes(range) .eq. 6,max(range(4:5)),1000)
  res@trYMinF               = where(dimsizes(range) .eq. 6,min(range(4:5)),1000)
  res@trXMinF = min(topo&$dimName$)
  res@trXMaxF = max(topo&$dimName$)
  res@trYLog                = True
  res@tmXBMajorLengthF = 0.01
  res@tmXBMajorOutwardLengthF = 0.01
  res@tmXBLabelDeltaF = -0.4
  res@tmYLLabelDeltaF = -0.4
  res@tmYLLabelFontHeightF = 0.03
  res@tmXBLabelFontHeightF = 0.03
  res@gsnYRefLine           = 999.9
  res@gsnFrame              = False
  res@gsnDraw               = False
  res@tmXTOn = False
  res@tmYROn = False
  res@vpHeightF = 0.5
  res@vpWidthF = 0.82
  res@vpXF = 0.135
  res@vpYF = 0.9
  res@tmYLLabelStride = 2
  res@tmXBMinorOn = False
  res@tmBorderThicknessF = 5
  res@gsnAboveYRefLineColor = "black"
  res@gsnBelowYRefLineColor = "black"
  res@xyCurveDrawOrder      = "postdraw"
  res@tfPolyDrawOrder = "Postdraw"
  res@tiYAxisString         = ""
  res@tmXBLabelFontHeightF = 0.03
  res@tmYLLabelFontHeightF = 0.03
  res@gsnLeftStringFontHeightF = 0.035
  res@gsnLeftStringOrthogonalPosF = 0.05
  ; res@gsnPresHgtHeightlabelOn = False
  exclude = (/"gsnStringBold","vc","gsnCorner","cn","mp","lb","Scale","preyear","tmLabelFontHeightF","pm","gsnPresHgtHeightlabelOn"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF
  delete(res@sfYArray)
  plot = gsn_csm_xy_dev(wks,topo&$dimName$,topo,res)
    if(isatt(opt,"gsnCornerString"))
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if
  return(plot)
end

undef("plot_topos")
function plot_topos (wks, range, opt)
local plotSize,plot,option,res,i,atts
begin
  plotSize = where(isint(opt),opt,get_res_value_keep(opt,"plotSize",1))
  plot = newPlots(plotSize)
  option = True
  copy_VarAtts(opt, option)
  res = True
    res@gsnDraw = False
    res@gsnFrame = False
  exclude := (/"cn","lb","Scale","preyear","gsnStringBold","tmLabelFontHeightF","vc","gsLineThicknessF","gsnLeftStrings","gsnRightStrings","gsnLeftStringOrthogonalPosnessF","tmXBLabelsOn"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  atts = (/"tmXBLabelsOn","tmYLLabelsOn","gsnCorner","gsnLeftString","gsnRightString"/)
  do i = 0, plotSize-1
    do a = 0, dimsizes(atts)-1
      copy_res_eq_with_index(option,res,atts(a),i)
      res@dim_to_mean = opt@dim_to_mean
    end do
    plot(i) = plot_topo(wks,range,res)
  end do
  return plot
end

undef("reg_dev") ; FX| reg_dev
function reg_dev (wks,ts,tp,ranges,opt)
local x,y,clr,res,t,plot,range,cor,rec,X,var
begin
  type = tp
  clr = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  res = opt
  res = True
  opt@polar = get_res_value_keep(opt,"polar",False)
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)
  ;plot 
  opt@data=1
  ; type@source = "jra55"
  type@year := ts&year
  opt@lonP0=False 
  opt@vertical=False
  if((ranges(3)-ranges(2)) .eq. 360)
    range = (/ranges(0)-2,ranges(1)+2,ranges(2),ranges(3)/)
  else
    range = (/ranges(0)-2,ranges(1)+2,ranges(2)-2,ranges(3)+2/)
  end if
  ; range = (/ranges(0)-2,ranges(1)+2,ranges(2)-2,ranges(3)+2/)
  ; range = ranges
  if(opt@polar) range(1:3) = (/90,0,360/) end if
  type@range := range
  X := process(type,opt)
  if(isatt(opt,"multi"))
    X  = (/X*opt@multi/)
  end if


  if(type .eq. 14) X = (/X*1e+6/) end if
  if(type .eq. 1) X = (/X*0.01/) end if
  if(isatt(opt, "designal"))then
    print("designal")
    X = (/designal(X,opt@designal)/)
  end if
  cor := escorc_n(ts, X, 0, 0)
  cor@Scale = 1
  rec := regCoef_n(ts, X, 0, 0)
  ; printVarSummary(rec)
  ; rec0 = dim_avg_n(rec,0)
  ; print(dim_avg_n(rec0,0))
  ; print(typeof(wks))
  if(.not. isgraphic(wks))
    copy_VarCoords(X(0,:,:), rec)
    return(rec)
  end if


  if(isatt(res,"cnLineThicknessF")) rec@cnLineThicknessF = res@cnLineThicknessF end if
  ; cor := smth9_Wrap(cor, 0.5, 0., False)

  ; cor@cnLevels         = (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)
    ; cor@cnLevels         = (/-0.9,-0.7,-0.5,-0.3,0.3,0.5,0.7,0.9/)
  ; cor@cnLevels         := (/-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99/)

  ; rec@cnFillColors = (/clr(0),clr(1),clr(3),clr(4),clr(5),clr(7),clr(8)/)
  cor@reverseColors    := get_res_value_keep(opt,"reverseColors",False)
  rec@Scale            := get_res_value_keep(opt,"Scale",1.)

  ; rec@cnFillColors = opt@cnFillColors
  ; if(isatt(opt,"cnLineThicknessF"))
  ; rec@cnLineThicknessF := opt@cnLineThicknessF
  ; end if
  rec@gsnContourNegLineDashPattern = get_res_value_keep(opt,"gsnContourNegLineDashPattern",1)
  copy_VarCoords( X(0,:,:), cor)
  copy_VarCoords( X(0,:,:), rec)
  if(get_res_value_keep(opt,"returnRec",False))
    return(rec)
  end if
;画图属性继承区，可折叠
  res@gsnDraw = False
  res@gsnFrame = False
  ; if(X@mon_name .eq. "JA")
    ; res@gsnRightString = get_res_value_keep(res,"addRightString","")+X@mon_name
  ; else
    ; res@gsnRightString = get_res_value_keep(res,"addRightString","")+get_res_value_keep(opt,"gsnRightString",X@mon_name) 

  ; end if
    res@lbLabelBarOn                 = get_res_value_keep(opt,"lbLabelBarOn",True)
  ; res@gsnRightString               = get_res_value_keep(opt,"addRightString","") ;+ X@mon_name+where(opt@preyear,"(-1)","")
    res@lbOrientation                = get_res_value_keep(opt,"lbOrientation","Horizontal")
  ; opt@polar                        = type .eq. 8
    ; res@tmXBLabelStride              = get_res_value_keep(opt,"tmXBLabelStride",2)
    ; res@tmYLLabelStride              = get_res_value_keep(opt,"tmYLLabelStride",2)
    ; rec@gsnContourNegLineDashPattern = get_res_value_keep(opt,"gsnContourNegLineDashPattern",12)
    res@gsnStringFontHeightF         = get_res_value_keep(opt,"gsnStringFontHeightF",0.027)
  ; if(res@lbOrientation .eq. "Vertical")
  ;   ; res@pmLabelBarHeightF = opt@vpHeightF*1.08
  ;   res@pmLabelBarHeightF = get_res_value_keep(opt,"pmLabelBarHeightF",opt@vpHeightF*1.08)
  ;   ; res@pmLabelBarWidthF = get_res_value_keep(opt,)
  ;   res@lbLabelFontHeightF = get_res_value_keep(opt,"lbLabelFontHeightF",0.03)
  ; ; else
  ; ;   res@pmLabelBarHeightF = get_res_value_keep(opt,"")
  ; ;   res@pmLabelBarWidthF = 1.0
  ; end if
  ; if(isatt(opt, "dots")) res = get_res_eq(opt,"dots") end if
  ; if(get_res_value_keep(opt,"dots",False)) 
    ; res@dots = True
    ; res@dotslon = opt@dotslon
    ; res@dotslat = opt@dotslat
    ; res@dotscolor = get_res_value_keep(opt,"dotscolor","tomato")
    ; res@dots1 = get_res_value_keep(opt,"dots1",False)
    ; res@dotslon1 = get_res_value_keep(opt,"dotslon1",False)
    ; res@dotslat1 = get_res_value_keep(opt,"dotslat1",False)
    ; res@dots2 = get_res_value_keep(opt,"dots2",False)
    ; res@dotslon2 = get_res_value_keep(opt,"dotslon2",False)
    ; res@dotslat2 = get_res_value_keep(opt,"dotslat2",False)
  ; end if
  if(opt@polar)then
    res@polar = True
    res@gsnAddCyclic = True
    res@vpHeightF = 0.8
    res@gsnPolar = "NH"
    else
    res@polar = False
    res@vpHeightF = get_res_value_keep(opt,"vpHeightF",0.4)
    res@vpWidthF = get_res_value_keep(opt,"vpWidthF",0.8)
    res@vpXF = 0.0
    res@gsnMaskLambertConformal = get_res_value_keep(opt,"gsnMaskLambertConformal",False)
    res@gsnMajorLonSpacing = get_res_value_keep(opt,"gsnMajorLonSpacing",10)
  end if
  ; gsnLeftString = get_res_value_keep(opt,"gsnLeftString",ts@name);+" cor. "+X@name) 
  gsnLeftString = get_res_value_keep(opt,"gsnLeftString",X@name+" linked to "+ts@name)
  ; if(ts@name .eq. "EAJII")
    ; res@gsnLeftString = get_res_value_keep(opt,"addLeftString","") + X@name
  ; else
    res@gsnLeftString = gsnLeftString
  ; end if
  ; res@gsnLeftString=item(a)+" "+ts@name+gsnLeftString
  ; res@xcnLevels = cor@cnLevels
  ; res@ycnLevels = rec@cnLevels

  cor@cnLinesOn = False
  res@plot_mode = get_res_value_keep(opt,"plot_mode",0)
  if(res@plot_mode .eq. 0)
    x = cor
    x@cnLevels := get_res_value_keep(opt,"cnLevels",(/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/))
    y = rec
  else
    x = rec
    if(isatt(opt,"cnLevels"))
      x@cnLevels := opt@cnLevels
    end if
    y = cor
    y@cnLevels := (/-t@r90,t@r90/)
    y@gsnContourNegLineDashPattern = 0
    if(isatt(opt,"cnLineThicknessF"))
      y@cnLineThicknessF = opt@cnLineThicknessF
    end if
  end if
  ; if(get_res_value_keep(opt,"cnLinesOn",True))
    if(get_res_value_keep(opt,"smoothing",False));平滑
        y := smth9_Wrap(y, 0.5, 0.5, False)
    end if
    if(isatt(opt,"cnFillColors")) x@cnFillColors := opt@cnFillColors end if
    if(isatt(opt,"mode") .and. opt@mode .eq. "stippling")
      y@mode = opt@mode
      print("stippling")
      y@cnLevels := (/-900,-t@r95,t@r95,900/)
      if(isatt(opt,"cnFillScaleF"))
        y@cnFillScaleF = opt@cnFillScaleF
      end if
      if(isatt(opt,"cnFillDotSizeF"))
        y@cnFillDotSizeF = opt@cnFillDotSizeF
      end if
      if(isatt(opt,"stipplingColor"))
        y@stipplingColor = opt@stipplingColor
      end if
      ; if( .not. get_res_value_keep(opt,"cnLinesOn",True))
      ;   y@cnLinesOn = False
      ; end
      var = [/x,y/]
      plot = plt_cn(wks,var,ranges,res)
    else
      var = [/x,y/]
      ; printVarSummary(res)
      plot = plt_cn(wks,var,ranges,res)
    end if
    ; plot = plt_cn(wks,x,ranges,res)
  ; end if
  


  if(get_res_value_keep(opt,"vector",False))
      type_u        = type
      if(isatt(opt,"surf_wind") .and. opt@surf_wind)
        type_u = 10
        type_v = 11
      else
        type_u = 3
        type_u@level  = get_res_value_keep(opt,"vclevel",850)
        type_v = 4
      end if
      type_u@source = "jra55"
      copy_VarAtts(type_u,type_v)
      u             = predata(type_u,ranges,opt)
      v             = predata(type_v,ranges,opt)
      rec_u         = regCoef_n(ts, u, 0, 0)
      rec_v         = regCoef_n(ts, v, 0, 0)
      t_v           = onedtond(rec_v@tval, dimsizes(rec_v))
      t_u           = onedtond(rec_u@tval, dimsizes(rec_u))
      rec_u         = where(t_u .le. t@t90 .and. t_u .ge. -t@t90 .and. t_v .le. t@t90 .and. t_v .ge. -t@t90, rec_u@_FillValue,rec_u)
      rec_v         = where(t_u .le. t@t90 .and. t_u .ge. -t@t90 .and. t_v .le. t@t90 .and. t_v .ge. -t@t90, rec_v@_FillValue,rec_v)
      copy_VarCoords(u(0,:,:), rec_u)
      copy_VarCoords(v(0,:,:), rec_v)
      ; printVarSummary(opt)
      add_vc_dev(plot,rec_u,rec_v,ranges,opt)
      ; vec = gsn_csm_vector(wks, rec_u, rec_v, resv)
      ; overlay(plot, vec)
  end if

    ;resc@cnLevels=cnLevels(type,:)
    ;rec_p=gsn_csm_contour(wks, rec, resc)
    ;overlay(ccr_p(a), rec_p)
    ; if(isatt(opt, "dotslon") .and. isatt(opt, "dotslat"))
    ;   resl=True
    ;   resl@gsLineColor= "tomato"
    ;   resl@gsLineThicknessF=8.0
    ;   str = unique_string("polyline")
    ;   plot(a)@$str$=gsn_add_polyline(wks, plot(a),opt@dotslon,opt@dotslat,resl)
    ; end if

    ; cnres           = True
    ; cnres@china     = True       ;draw china map or not
    ; cnres@river     = True       ;draw chan gjiang&huanghe or not
    ; cnres@province  = True       ;draw province boundary or not
    ; cnres@nanhai    = True       ;draw nanhai or not 
    ; cnres@diqu      = False       ; draw diqujie or not

    ; ;chinamap = add_china_map(wks,ccr_p(2*a),cnres);draw(ccr_p(a))
    ; ;frame(wks)
    ; delete([/X,tem0,tem1,over1,over0/])
  print("success!")
  if(get_res_value_keep(opt,"gsnDraw",True)) draw(plot) end if
  if(get_res_value_keep(opt,"gsnFrame",True)) frame(wks) end if
  return(plot)
end

undef("reg_ver_dev") ; FX| reg_dev
function reg_ver_dev(wks,ts,type,ranges,opt)
  begin
  clr = (/"#407933","#72BF4F","#9BCE7F","#C1E0B8","#FFFFFF","#F6E9BC","#F1CD5C","#F0BF2A","#A57E1E"/)
  res = True
    res@gsnDraw = False
    res@gsnFrame = False
  opt@polar = get_res_value_keep(opt,"polar",False)
  ; opt@with  = get_res_value_keep(opt,"with",(/ts0@type,ts1@type/))
  nyear     = dimsizes(ts&year)
  
  opt@preyear = get_res_value_keep(opt,"preyear",False)
  t = t_value(nyear-2)

  type@year := ts&year 
  opt@lonP0=False 
  opt@vertical=False
  if(opt@polar) type@range(1:3) = (/90,0,360/) end if
  X := process(type,opt)

  if(isatt(opt,"multi"))
    X  = (/X*opt@multi/)
  end if


  if(type .eq. 14) X = (/X*1e+6/) end if
  if(type .eq. 1) X = (/X*0.01/) end if
  cor := escorc_n(ts, X, 0, 0)
  cor@Scale = 1
  rec := regCoef_n(ts, X, 0, 0)
  ; printVarSummary(rec)
  ; rec0 = dim_avg_n(rec,0)
  ; print(dim_avg_n(rec0,0))
  ; print(typeof(wks))
  ; if(.not. isgraphic(wks))
  ;   copy_VarCoords(X(0,:,:), rec)
  ;   return(rec)
  ; end if
  rec@gsnContourNegLineDashPattern = get_res_value_keep(opt,"gsnContourNegLineDashPattern",12)
  exclude = ""
  copy_VarAtts_match(opt,res,res_plot,exclude)

  ; if(isatt(res,"cnLineThicknessF")) rec@cnLineThicknessF = res@cnLineThicknessF end if
  ; ; cor := smth9_Wrap(cor, 0.5, 0., False)
  
  ; ; cor@cnLevels         = (/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/)
  ;   ; cor@cnLevels         = (/-0.9,-0.7,-0.5,-0.3,0.3,0.5,0.7,0.9/)
  ; ; cor@cnLevels         := (/-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99/)

  ; ; rec@cnFillColors = (/clr(0),clr(1),clr(3),clr(4),clr(5),clr(7),clr(8)/)
  ; cor@reverseColors    := get_res_value_keep(opt,"reverseColors",False)
  ; rec@Scale            := get_res_value_keep(opt,"Scale",1.)

  ; ; rec@cnFillColors = opt@cnFillColors
  ; ; if(isatt(opt,"cnLineThicknessF"))
  ; ; rec@cnLineThicknessF := opt@cnLineThicknessF
  ; ; end if

  copy_VarCoords_not_n(X,cor,0)
  copy_VarCoords_not_n(X,rec,0)
  ; printVarSummary( cor)
  ; if(get_res_value_keep(opt,"returnRec",False))
  ;   return(rec)
  ; end if
;画图属性继承区，可折叠

  ; if(X@mon_name .eq. "JA")
    ; res@gsnRightString = get_res_value_keep(res,"addRightString","")+X@mon_name
  ; else
    ; res@gsnRightString = get_res_value_keep(res,"addRightString","")+get_res_value_keep(opt,"gsnRightString",X@mon_name) 

  ; end if
  ;   res@lbLabelBarOn                 = get_res_value_keep(opt,"lbLabelBarOn",True)
  ; ; res@gsnRightString               = get_res_value_keep(opt,"addRightString","") ;+ X@mon_name+where(opt@preyear,"(-1)","")
  ;   res@lbOrientation                = get_res_value_keep(opt,"lbOrientation","Horizontal")
  ; ; opt@polar                        = type .eq. 8
  ;   res@tmXBLabelStride              = get_res_value_keep(opt,"tmXBLabelStride",2)
  ;   res@tmYLLabelStride              = get_res_value_keep(opt,"tmYLLabelStride",2)

  ;   res@gsnStringFontHeightF         = get_res_value_keep(opt,"gsnStringFontHeightF",0.027)
  ; if(res@lbOrientation .eq. "Vertical")
  ;   ; res@pmLabelBarHeightF = opt@vpHeightF*1.08
  ;   res@pmLabelBarHeightF = get_res_value_keep(opt,"pmLabelBarHeightF",opt@vpHeightF*1.08)
  ;   ; res@pmLabelBarWidthF = get_res_value_keep(opt,)
  ;   res@lbLabelFontHeightF = get_res_value_keep(opt,"lbLabelFontHeightF",0.03)
  ; ; else
  ; ;   res@pmLabelBarHeightF = get_res_value_keep(opt,"")
  ; ;   res@pmLabelBarWidthF = 1.0
  ; end if
  ; if(isatt(opt, "dots")) res = get_res_eq(opt,"dots") end if
  ; if(get_res_value_keep(opt,"dots",False)) 
    ; res@dots = True
    ; res@dotslon = opt@dotslon
    ; res@dotslat = opt@dotslat
    ; res@dotscolor = get_res_value_keep(opt,"dotscolor","tomato")
    ; res@dots1 = get_res_value_keep(opt,"dots1",False)
    ; res@dotslon1 = get_res_value_keep(opt,"dotslon1",False)
    ; res@dotslat1 = get_res_value_keep(opt,"dotslat1",False)
    ; res@dots2 = get_res_value_keep(opt,"dots2",False)
    ; res@dotslon2 = get_res_value_keep(opt,"dotslon2",False)
    ; res@dotslat2 = get_res_value_keep(opt,"dotslat2",False)
  ; end if
  if(opt@polar)then
    res@polar = True
    res@gsnAddCyclic = True
    res@vpHeightF = 0.8
    res@gsnPolar = "NH"
    else
    res@polar = False
    res@vpHeightF = get_res_value_keep(opt,"vpHeightF",0.4)
    res@vpWidthF = get_res_value_keep(opt,"vpWidthF",0.8)
    res@vpXF = 0.0
    res@gsnMaskLambertConformal = get_res_value_keep(opt,"gsnMaskLambertConformal",False)
    res@gsnMajorLonSpacing = get_res_value_keep(opt,"gsnMajorLonSpacing",10)
  end if
  ; gsnLeftString = get_res_value_keep(opt,"gsnLeftString",ts@name);+" cor. "+X@name) 
  ; gsnLeftString = get_res_value_keep(opt,"gsnLeftString",X@name+" linked to "+ts@name)
  ; if(ts@name .eq. "EAJII")
    ; res@gsnLeftString = get_res_value_keep(opt,"addLeftString","") + X@name
  ; else
    ; res@gsnLeftString = gsnLeftString
  ; end if
  ; res@gsnLeftString=item(a)+" "+ts@name+gsnLeftString
  ; res@xcnLevels = cor@cnLevels
  ; res@ycnLevels = rec@cnLevels

  cor@cnLinesOn = False
  res@plot_mode = get_res_value_keep(opt,"plot_mode",0)
  if(res@plot_mode .eq. 0)
    x = cor
    x@cnLevels := get_res_value_keep(opt,"cnLevels",(/-t@r999,-t@r99,-t@r95,-t@r90,t@r90,t@r95,t@r99,t@r999/))
    y = rec
  else
    x = rec
    if(isatt(opt,"cnLevels"))
      x@cnLevels := opt@cnLevels
    end if
    y = cor
    y@cnLevels := (/-t@r90,t@r90/)
    y@gsnContourNegLineDashPattern = 0
    if(isatt(opt,"cnLineThicknessF"))
      y@cnLineThicknessF = opt@cnLineThicknessF
    end if
  end if
  if(isatt(opt,"cnFillColors")) x@cnFillColors := opt@cnFillColors end if

  if(get_res_value_keep(opt,"cnLinesOn",True))
    ; if(get_res_value_keep(opt,"smoothing",False));平滑
    ;     y := smth9_Wrap(y, 0.5, 0.5, False)
    ; end if
    if(isatt(opt,"mode") .and. opt@mode .eq. "stippling")
      print("stippling")
      y@cnLevels := (/-900,-t@r95,t@r95,900/)
      if(isatt(opt,"cnFillScaleF"))
        y@cnFillScaleF = opt@cnFillScaleF
      end if
      if(isatt(opt,"cnFillDotSizeF"))
        y@cnFillDotSizeF = opt@cnFillDotSizeF
      end if
      if(isatt(opt,"stipplingColor"))
        y@stipplingColor = opt@stipplingColor
      end if
      var = [/x,y/]
      plot = plt_cn_ver(wks,var,ranges,res)
    else
      var = [/x,y/]
      plot = plt_cn_ver(wks,var,ranges,res)
    end if
  else
    plot = plt_cn_ver(wks,x,ranges,res)
  end if
  if(get_res_value_keep(opt,"vector",False))
      type_u        = type
      if(is_element("lat",opt@dim_to_avg))
        type_u = "u"
      else if(is_element("lon",opt@dim_to_avg))
        type_u = "v"
      end if
      end if
      type_vv = "vv"
      type_u@source = "jra55"
      copy_VarAtts(type_u,type_vv)
      u             = process(type_u,opt)
      v             = process(type_vv,opt)
      rec_u         = regCoef_n(ts, u, 0, 0)
      rec_v         = regCoef_n(ts, v, 0, 0)
      t_v           = onedtond(rec_v@tval, dimsizes(rec_v))
      t_u           = onedtond(rec_u@tval, dimsizes(rec_u))
      rec_u         = where(t_u .le. t@t90 .and. t_u .ge. -t@t90 .and. t_v .le. t@t90 .and. t_v .ge. -t@t90, rec_u@_FillValue,rec_u)
      rec_v         = where(t_u .le. t@t90 .and. t_u .ge. -t@t90 .and. t_v .le. t@t90 .and. t_v .ge. -t@t90, rec_v@_FillValue,rec_v)
      copy_VarCoords(u(0,:,:), rec_u)
      copy_VarCoords(v(0,:,:), rec_v)
      ; printVarSummary(opt)
      add_vc_dev(plot,rec_u,rec_v,ranges,opt)
      ; vec = gsn_csm_vector(wks, rec_u, rec_v, resv)
      ; overlay(plot, vec)
  end if

    ;resc@cnLevels=cnLevels(type,:)
    ;rec_p=gsn_csm_contour(wks, rec, resc)
    ;overlay(ccr_p(a), rec_p)
    ; if(isatt(opt, "dotslon") .and. isatt(opt, "dotslat"))
    ;   resl=True
    ;   resl@gsLineColor= "tomato"
    ;   resl@gsLineThicknessF=8.0
    ;   str = unique_string("polyline")
    ;   plot(a)@$str$=gsn_add_polyline(wks, plot(a),opt@dotslon,opt@dotslat,resl)
    ; end if

    ; cnres           = True
    ; cnres@china     = True       ;draw china map or not
    ; cnres@river     = True       ;draw chan gjiang&huanghe or not
    ; cnres@province  = True       ;draw province boundary or not
    ; cnres@nanhai    = True       ;draw nanhai or not 
    ; cnres@diqu      = False       ; draw diqujie or not

    ; ;chinamap = add_china_map(wks,ccr_p(2*a),cnres);draw(ccr_p(a))
    ; ;frame(wks)
    ; delete([/X,tem0,tem1,over1,over0/])
  print("success!")
  if(get_res_value_keep(opt,"gsnDraw",True)) draw(plot) end if
  if(get_res_value_keep(opt,"gsnFrame",True)) frame(wks) end if
  plot@levels = x&level
  return(plot)
end


undef("add_Yref")
procedure add_Yref (plotid,yref)
local tem_wks,res_poly,i,str,j,xMin,xMax
begin
  tem_wks = NhlGetParentWorkstation(plotid(0))
  getvalues plotid(0)
    "trXMinF": trXMinF
    "trXMaxF": trXMaxF
    "tmBorderThicknessF":tmBorderThicknessF
  end getvalues
  xMin = get_res_value_keep(yref, "polyYRefMin", trXMinF-1)
  xMax = get_res_value_keep(yref, "polyYRefMax", trXMaxF+1)
  res_poly = True
  res_poly@gsLineColor = get_res_value_keep(yref,"polyYRefColor","dodgerblue")
  res_poly@gsLineDashPattern = get_res_value_keep(yref,"polyYRefDashPattern",0)
  res_poly@gsLineThicknessF = get_res_value_keep(yref,"polyYRefThicknessF",tmBorderThicknessF)
  do j = 0, dimsizes(plotid)-1
    if(isArray(yref))
      do i = 0, dimsizes(yref)-1
        str = unique_string("polyline")
        plotid@$str$ = gsn_add_polyline(tem_wks, plotid(j),(/xMin,xMax/),(/yref(i),yref(i)/),res_poly)
      end do 
    else
      str = unique_string("polyline")
      plotid@$str$ = gsn_add_polyline(tem_wks, plotid(j),(/xMin,xMax/),(/yref,yref/),res_poly)
    end if
  end do
end

undef("add_errorBar")
procedure add_errorBar(plot,x,upper,lower,opt)
local res_bar,w,upperLine,lowerLine,str,vertical,tem_wks,barOffsetXF
begin
  tem_wks = NhlGetParentWorkstation(plot)
  res_bar := True
    res_bar@tfPolyDrawOrder = "Postdraw"
    res_bar@gsLineThicknessF = 5.
    copy_VarAtts_match(opt,res_bar,"gs","")
    w := get_res_value_keep(opt,"barWidth",0.1)
    barOffsetXF = get_res_value_keep(opt,"barOffsetXF",0)
    upperLine = (/x-w+barOffsetXF,x+w+barOffsetXF,upper,upper/)
    lowerLine =  (/x-w+barOffsetXF,x+w+barOffsetXF,lower,lower/)
    vertical =  (/x+barOffsetXF,x+barOffsetXF,upper,lower/)
    str = unique_string("plolyline" )
    plot@$str$ = gsn_add_polyline(tem_wks, plot,upperLine(:1),upperLine(2:),res_bar)
    str = unique_string("plolyline" )
    plot@$str$ = gsn_add_polyline(tem_wks, plot,lowerLine(:1),lowerLine(2:),res_bar)
    str = unique_string("plolyline" )
    plot@$str$ = gsn_add_polyline(tem_wks, plot, vertical(:1),vertical(2:),res_bar)
end

undef("plot_bar")
function plot_bar (wks,index,opt)
local type,ts0,i,plot,count,res,x,singleBar,barOffsetXF,dim
begin
  type = typeof(index)
  if(type .eq. "list")
    ts0 = index[0]
    count = ListCount(index)
    singleBar = count .eq. 1
    else
      if(dimsizes(dimsizes(index)) .eq. 1)
        ts0 = index
        singleBar = True
      else
        ts0 = index(0,:)
        ts1 = index(1,:)
        singleBar = False
      end if  
  end if
  ; ts0 = index
  ; singleBar = True
;
  res = True
    res@gsnXYBarChart = True
    res@tmBorderThicknessF = 4.
    res@gsnYRefLine = 0.
    res@gsnYRefLineThicknessF = 4.
    ; c = NhlNewColor(wks, 11/255., 93/255., 175/255.)
    res@gsnAboveYRefLineColor = "Tomato"
    res@gsnBelowYRefLineColor = "steelblue"
    ; res@gsnAboveYRefLineBarColors = "#0b5daf"
    ; res@gsnDraw = False
    ; res@gsnFrame = False
    ; res@gsLineColor = "steelblue"
    res@trXMinF = 0
    res@trXMaxF = dimsizes(ts0)
    res@gsnXYBarChartBarWidth        = 0.29
    ; res@gsnXYBarChartOutlineThicknessF = 0.1
    res@tmYLMinorOn = False
    res@tmYLMajorLengthF = 0.01
    res@tmYLLabelDeltaF = -0.3
    res@tmXBLabelDeltaF = -0.3
    res@tmXBMinorOn = False
    res@tmXBMajorLengthF = 0.01
    res@tmXBMajorOutwardLengthF = 0.01
    res@tmXBMode = "Explicit"
    if(isdimnamed(ts0, 0))
      res@tmXBLabels = ts0&$ts0!0$
    else
      res@tmXBLabels = ispan(1, dimsizes(ts0), 1)
    end if
    ; if(isatt(ts0,"axis"))
    ;   res@tmXBLabels = ts0@axis
    ; end if
    res@tiYAxisString = ""
    ; res@tmXBLabelAngleF = 30
    ; res@tmXBLabelJust = "centerright"
    res@tmXBLabelFontHeightF = 0.013
    res@tmYLLabelFontHeightF = 0.013
    res@vpWidthF = 0.85
    res@vpHeightF = 0.3
    res@vpXF = 0.1
    res@tmYROn = False
    res@tmXTOn = False
    ; res@gsnLeftString = "EAJII"
    res@gsnLeftStringFontHeightF = 0.02
    res@xyLineColor = "transparent"
    if(isatt(opt, "barBorderColor"))then
      res@xyLineColor = opt@barBorderColor
    end if
    if(isatt(opt, "barBorderThicknessF"))then
      res@xyLineThicknessF = opt@barBorderThicknessF
    end if
    if(isatt(index, "barBorderColor"))then
      res@xyLineColor = index@barBorderColor
    end if
    if(isatt(index, "barBorderThicknessF"))then
      res@xyLineThicknessF = index@barBorderThicknessF
    end if
    ; res@xyLineColor = res@gsnAboveYRefLineColor
  exclude := (/"time","_FillValue","trend_scale","txPos","gsnCorner"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  copy_VarAtts_match(ts0,res,res_plot,exclude)
  dim = dimsizes(res@tmXBLabels)
    res@trXMaxF := res@trXMaxF+get_res_value_keep(opt,"extend",1)
    ; if(isatt(opt, "extend"))then
    ;   res@trXMinF = res@trXMinF-opt@extend
    ; end if
    res@tmXBValues := ispan(1,dim,1)
    res@tmXBMajorThicknessF = res@tmBorderThicknessF
    res@tmYLMajorThicknessF = res@tmBorderThicknessF
  if(isatt(res,"tmYLTickSpacingF"))
    res@tmYLMode = "Manual"
  end if
  if(isatt(res,"tmYLValues"))
    res@tmYLMode = "Explicit"
  end if
  if(isatt(ts0,"axis"))
    x = ind_dev(res@tmXBLabels,ts0@axis)+1
  else
    x = ispan(1,dimsizes(res@tmXBLabels),1)
  end if
  print(res)
  barOffsetXF = get_res_value_keep(ts0,"barOffsetXF",0)
  plot = gsn_csm_xy(wks,x+barOffsetXF,ts0,res)
  ; if(isatt(ts0,"opRectanglePos"))
  ;   res_rt = True
  ;     res_rt@rtFillColor = res@gsnAboveYRefLineColor
  ;   copy_VarAtts_match(ts0,res_rt,"rt","")
  ;   add_box(plot,ts0@opRectanglePos(0),ts0@opRectanglePos(1),res_rt)
  ; end if 

  option = True
  copy_VarAtts_eq(opt,option,(/"polyYRef","polyBox"/))
  copy_VarAtts_eq(ts0,option,(/"polyYRef","polyBox"/))
  if(isatt(option, "polyYRef"))
    yref = option@polyYRef
    copy_VarAtts_eq(option,yref,"polyYRef")
    add_Yref(plot,yref)
  end if

  if(isatt(option,"polyBox"))
    res_box = get_res_value_keep(option,"polyBoxText",True)
    res_box@gsFillColor = get_res_value_keep(option,"polyBoxColor",0.5)
    res_box@txFontHeightF = get_res_value_keep(option,"polyBoxTextFontHeightF",0.5)
    res_box@txOffsetXF = get_res_value_keep(option,"polyBoxTextOffsetXF",0)
    res_box@txOffsetYF = get_res_value_keep(option,"polyBoxTextOffsetYF",0)
    res_box@bxTextPosition = get_res_value_keep(option,"polyBoxTextPos","center")
    add_box(plot,option@polyBox(0),option@polyBox(1),option@polyBox(2),option@polyBox(3),res_box)
  end if

  if(isatt(ts0,"polyXF"))
    res_poly = True
    res_poly@gsFillColor = res@gsnAboveYRefLineColor
    str = unique_string("poly")
    plot@$str$ = gsn_add_polygon(wks,plot,ts0@polyXF,ts0@polyYF,res_poly)
  end if

  if(isatt(ts0,"text"))
    res_text = True
    res_text@txFontHeightF = 0.01
    res_text = get_att_eq(ts0,"tx")
    text = gsn_add_text(wks,plot,ts0@text,ts0@txPos(0),ts0@txPos(1),res_text)
  end if
  ; print(get_cpu_time())
  if(.not. singleBar)
    do i = 1, count-1
      ts := index[i]
      if(isatt(ts,"axis"))
        x = ind_dev(res@tmXBLabels,ts@axis)+1
      else
        x = ispan(1,dimsizes(res@tmXBLabels),1)
      end if
      copy_VarAtts_match(ts,res,res_plot,exclude)
      res@xyLineColor = res@gsnAboveYRefLineColor
      barOffsetXF = get_res_value_keep(ts,"barOffsetXF",0)
      ploto = gsn_csm_xy(wks,x+barOffsetXF,ts,res)
      ; printVarSummary(ploto)
      ; printVarSummary(plot)
      overlay(plot,ploto)
      copy_VarAtts(ploto,plot)
      ; printVarSummary(plot)
      ; if(isatt(ts,"polyXF"))
      ;   res_poly = True
      ;   res_poly@gsFillColor = ts@gsnAboveYRefLineColor
      ;   str = unique_string("poly")
      ;   plot@$str$ = gsn_add_polygon(wks,plot,ts@polyXF,ts@polyYF,res_poly)
      ; end if
      ; if(isatt(ts,"opRectanglePos"))
      ;   res_rt = True
      ;     res_rt@rtFillColor = ts@gsnAboveYRefLineColor
      ;   copy_VarAtts_match(ts,res_rt,"rt","")
      ;   add_box(plot,ts@opRectanglePos(0),ts@opRectanglePos(1),res_rt)
      ; end if
      if(isatt(ts,"text"))
        res_text = True
        res_text@txFontHeightF = 0.01
        res_text = get_att_eq(ts,"tx")
        text = gsn_add_text(wks,plot,ts@text,ts@txPos(0),ts@txPos(1),res_text)
      end if
    end do
  end if
  if(isatt(opt,"gsnCornerString"))
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeightF = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if
  if(isatt(opt,"errorbar"))
    errorbars = opt@errorbar
    if(typeof(errorbars) .eq. "list")
      do i = 0, ListCount(errorbars)-1
        errorbar = errorbars[i]
        res_bar := True
        res_bar@tfPolyDrawOrder = "Postdraw"
        x := errorbar@loc(0)
        y := errorbar@loc(1)
        h := get_res_value_keep(errorbar,"height",errorbar)
        ; h := errorbars@height
        w := get_res_value_keep(errorbar,"width",0.1)
        upper = (/x-w,x+w,y+h,y+h/)
        lower =  (/x-w,x+w,y-h,y-h/)
        vertical =  (/x,x,y+h,y-h/)
        str = unique_string("plolyline" )
        plot@$str$ = gsn_add_polyline(wks,plot,upper(:1),upper(2:),res_bar)
        str = unique_string("plolyline" )
        plot@$str$  = gsn_add_polyline(wks, plot,lower(:1),lower(2:),res_bar)
        str = unique_string("plolyline" )
        plot@$str$  = gsn_add_polyline(wks, plot, vertical(:1),vertical(2:),res_bar)
      end do
    ; else
    ;   tem := errorbar
    ;     upper = (/tem(0)-1,tem(0)+1,tem(1)+1,tem(1)+1/)
    ;     lower = (/tem(0)-1,tem(0)+1,tem(1)-1,tem(1)-1/)
    ;     vertical = (/tem(0),tem(0),tem(0)+1,tem(0)-1/)
    ;     plt_upper = gsn_add_polyline(wks,plot,upper(:1),upper(2:),True)
    ;     plt_lower = gsn_add_polyline(wks, plot,lower(:1),lower(2:0),True)
    ;     plt_ver = gsn_add_polyline(wks, plot, vertical(:1),vertical(2:),True)
    end if
  end if
  ; draw(plot)
  return(plot)
end

undef("add_singleBar")
procedure add_singleBar (plotid,position[1],ts0)
local tem_wks,plot,trXMinF,trXMaxF,tmXBLabels,tmXBValues,res
begin
tem_wks = NhlGetParentWorkstation(plotid)
getvalues plotid
  "trXMinF" : trXMinF
  "trXMaxF" : trXMaxF
  "tmXBValues" : tmXBValues
  "tmXBLabels" : tmXBLabels
end getvalues


if(position .le. trXMinF)
  trXMinF := position-1
end if

if(position .ge. trXMaxF)
  trXMaxF := position+1
end if

if(isatt(ts0, "trXMaxF"))then
  trXMaxF := ts0@trXMaxF
end if

if(isatt(ts0, "trXMinF"))then
  trXMinF := ts0@trXMinF
end if

if(.not. is_element(position,tmXBValues))
    tmXBValues := append(position,tmXBValues)
  if(isatt(ts0,"tmXBLabels"))
    tmXBLabels := append(ts0@tmXBLabels,tmXBLabels)
  else
    tmXBLabels := append(tostring(position),tmXBLabels)
  end if
end if

setvalues plotid
  "trXMinF" : trXMinF
  "trXMaxF" : trXMaxF
  "tmXBValues" : tmXBValues
  "tmXBLabels" : tmXBLabels
end setvalues

res = True
    res@gsnXYBarChart = True
    res@gsnYRefLine = 0.
    res@gsnYRefLineThicknessF = 5.
    res@gsnAboveYRefLineColor = "steelblue"
    res@gsnBelowYRefLineColor = "steelblue"
    res@gsnDraw = False
    res@gsnFrame = False
    ; res@gsLineColor = "steelblue"
    res@trXMinF = trXMinF
    res@trXMaxF = trXMaxF
    res@gsnXYBarChartBarWidth        = 0.29
    ; res@gsnXYBarChartOutlineThicknessF = 0.1
    res@tmYLMinorOn = False
    res@tmYLMajorLengthF = 0.005
    res@tmXBMinorOn = False
    res@tmXBMajorLengthF = 0.005
    res@tmXBMajorOutwardLengthF = 0.005
    res@tmXBMode = "Explicit"
    res@tiYAxisString = ""
    res@tmXBLabelJust = "centerright"
    res@tmXBLabelFontHeightF = 0.01
    res@tmYLLabelFontHeightF = 0.013
    res@vpWidthF = 0.85
    res@vpHeightF = 0.3
    res@vpXF = 0.1
    res@tmYROn = False
    res@tmXTOn = False
    res@gsnLeftStringFontHeightF = 0.015
    res@tmBorderThicknessF = 4.
  exclude = (/"time","_FillValue","trend_scale","txPos","gsnCorner"/)
  ; copy_VarAtts_match(opt,res,res_plot,exclude)
  copy_VarAtts_match(ts0,res,res_plot,exclude)
    res@gsnLeftString = ""
  ; dim = dimsizes(res@tmXBLabels)
    ; res@trXMaxF = dim+get_res_value_keep(opt,"extend",1)
    ; res@tmXBValues = ispan(1,dim,1)
    res@xyLineOpacityF = 0
    res@xyLineColor = res@gsnAboveYRefLineColor
    res@tmXBMajorThicknessF = res@tmBorderThicknessF
    res@tmYLMajorThicknessF = res@tmBorderThicknessF
  ; x = ind_dev(res@tmXBLabels,ts0@axis)+1
  res@tmXBLabelsOn = True
  res@tmXBOn = True
  ; printVarSummary(res)
  barOffsetXF = get_res_value_keep(ts0,"barOffsetXF",0)
  plot = gsn_csm_xy(tem_wks,position+barOffsetXF,ts0,res)

  ; draw(plot)
  ; if(isatt(ts0,"polyLineYF"))
  ;   res_poly = True
  ;   res_poly@gsLineColor = res@gsLineColor
  ;   if(isArray(ts0@polyLineYF))
  ;     do i = 0, dimsizes(ts0@polyLineYF)-1
  ;       str = unique_string("polyline")
  ;       plot@$str$ = gsn_add_polyline(tem_wks, plot,(/res@trXMinF,res@trXMaxF/),(/ts0@polyLineYF(i),ts0@polyLineYF(i)/),res_poly)
  ;     end do 
  ;   else
  ;     str = unique_string("polyline")
  ;     plot@$str$ = gsn_add_polyline(tem_wks, plot,(/res@trXMinF,res@trXMaxF/),(/ts0@polyLineYF,ts0@polyLineYF/),res_poly)
  ;   end if
  ; end if
  ; if(isatt(ts0,"polyXF"))
  ;   res_poly = True
  ;   res_poly@gsFillColor = res@gsnAboveYRefLineColor
  ;   str = unique_string("poly")
  ;   plot@$str$ = gsn_add_polygon(tem_wks,plot,ts0@polyXF,ts0@polyYF,res_poly)
  ; end if

  ; if(isatt(ts0,"text"))
  ;   res_text = True
  ;   res_text@txFontHeightF = 0.01
  ;   text = gsn_add_text(tem_wks,plot,ts0@text,ts0@txPos(0),ts0@txPos(1),res_text)
  ; end if
  overlay(plotid, plot)
  copy_VarAtts(plot, plotid)
end

undef("add_bar")
procedure add_bar (plotid,index)
local tem_wks,type,ts0,count,singleBar,plot,dimName,barOffsetXF,res
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  type = typeof(index)
  if(type .eq. "list")
    ts0 = index[0]
    count = ListCount(index)
    singleBar = count .eq. 1
    else
      if(dimsizes(dimsizes(index)) .eq. 1)
        ts0 = index
        singleBar = True
      else
        ts0 = index(0,:)
        ts1 = index(1,:)
        singleBar = False
      end if  
  end if
  res = True
    res@gsnXYBarChart = True
    res@gsnYRefLine = 0.
    res@gsnAboveYRefLineColor = "steelblue"
    res@gsnBelowYRefLineColor = "steelblue"
    res@gsnDraw = False
    res@gsnFrame = False
    res@trXMinF = 0
    res@gsnXYBarChartBarWidth        = 0.29
    ; res@gsnXYBarChartOutlineThicknessF = 0.1
    res@gsnLeftStringFontHeightF = 0.015
    res@tmBorderThicknessF = 4.
    res@xyLineColor = "transparent"
    if(isatt(index, "barBorderColor"))then
      res@xyLineColor = index@barBorderColor
    end if
    if(isatt(index, "barBorderThicknessF"))then
      res@xyLineThicknessF = index@barBorderThicknessF
    end if
  exclude = (/"time","_FillValue","trend_scale","txPos","gsnCorner"/)
  copy_VarAtts_match(ts0,res,res_plot,exclude)
    res@gsnLeftString = ""
    ; res@xyLineColor = res@gsnAboveYRefLineColor
    res@tmXBMajorThicknessF = res@tmBorderThicknessF
    res@tmYLMajorThicknessF = res@tmBorderThicknessF

  dimName = getvardims(ts0)
  x = ispan(1,dimsizes(ts0),1)
  barOffsetXF = get_res_value_keep(ts0,"barOffsetXF",0)
  print(res)
  plot = gsn_csm_xy(tem_wks,x+barOffsetXF,ts0,res)


  option = True
  copy_VarAtts_eq(ts0,option,(/"polyYRef","polyBox"/))
  if(isatt(option,"polyBox"))
    res_box = get_res_value_keep(option,"polyBoxText",True)
    res_box@gsFillColor = get_res_value_keep(option,"polyBoxColor",0.5)
    res_box@txFontHeightF = get_res_value_keep(option,"polyBoxTextFontHeightF",0.5)
    res_box@txOffsetXF = get_res_value_keep(option,"polyBoxTextOffsetXF",0)
    res_box@txOffsetYF = get_res_value_keep(option,"polyBoxTextOffsetYF",0)
    res_box@bxTextPosition = get_res_value_keep(option,"polyBoxTextPos","center")
    add_box(plotid,option@polyBox(0),option@polyBox(1),option@polyBox(2),option@polyBox(3),res_box)
  end if
  if(isatt(ts0,"polyXF"))
    res_poly = True
    res_poly@gsFillColor = res@gsnAboveYRefLineColor
    str = unique_string("poly")
    plotid@$str$ = gsn_add_polygon(tem_wks,plotid,ts0@polyXF,ts0@polyYF,res_poly)
  end if

  if(isatt(ts0,"text"))
    res_text = True
    res_text@txFontHeightF = 0.01
    text = gsn_add_text(tem_wks,plotid,ts0@text,ts0@txPos(0),ts0@txPos(1),res_text)
  end if
  overlay(plotid, plot)
  copy_VarAtts(plot, plotid)


  ; if(.not. singleBar)
  ;   do i = 1, count-1
  ;     ts := index[i]
  ;     x := ind_dev(res@tmXBLabels,ts@axis)+1
  ;     copy_VarAtts_match(ts,res,res_plot,exclude)
  ;     res@xyLineColor = res@gsnAboveYRefLineColor
  ;     barOffsetXF = get_res_value_keep(ts,"barOffsetXF",0)
  ;     ; ploto = gsn_csm_xy(wks,x+barOffsetXF,ts,res)
  ;     ; overlay(plot,ploto)
  ;     if(isatt(ts,"polyXF"))
  ;       res_poly = True
  ;       res_poly@gsFillColor = ts@gsnAboveYRefLineColor
  ;       str = unique_string("poly")
  ;       plot@$str$ = gsn_add_polygon(wks,plot,ts@polyXF,ts@polyYF,res_poly)
  ;     end if
  ;     if(isatt(ts,"text"))
  ;       res_text = True
  ;       res_text@txFontHeightF = 0.01
  ;       text = gsn_add_text(wks,plot,ts@text,ts@txPos(0),ts@txPos(1),res_text)
  ;     end if
  ;   end do
  ; end if
  ; if(isatt(opt,"gsnCornerString"))
  ;   corner = opt@gsnCornerString
  ;   if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
  ;     opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
  ;   end if
  ;   copy_VarAtts_eq(opt,corner,"gsnCorner")
  ;   ; res_text = get_res_eq(opt,"gsnCorner")
  ;   add_CornerString(plot,corner)
  ; end if
  ; if(isatt(opt,"errorbar"))
  ;   errorbar = opt@errorbar

  ;   if(typeof(errorbar) .eq. "list")
  ;     do i = 0, ListCount(errorbar)-1
  ;       res_bar := errorbar[i]
  ;       res_bar@tfPolyDrawOrder = "Postdraw"
  ;       x := res_bar@loc(0)
  ;       y := res_bar@loc(1)
  ;       h := res_bar@height
  ;       w := res_bar@width
  ;       upper = (/x-w,x+w,y+h,y+h/)
  ;       lower =  (/x-w,x+w,y-h,y-h/)
  ;       vertical =  (/x,x,y+h,y-h/)
  ;       str = unique_string("plolyline" )
  ;       plot@$str$ = gsn_add_polyline(wks,plot,upper(:1),upper(2:),res_bar)
  ;       str = unique_string("plolyline" )
  ;       plot@$str$  = gsn_add_polyline(wks, plot,lower(:1),lower(2:),res_bar)
  ;       str = unique_string("plolyline" )
  ;       plot@$str$  = gsn_add_polyline(wks, plot, vertical(:1),vertical(2:),res_bar)
  ;     end do
  ;   ; else
  ;   ;   tem := errorbar
  ;   ;     upper = (/tem(0)-1,tem(0)+1,tem(1)+1,tem(1)+1/)
  ;   ;     lower = (/tem(0)-1,tem(0)+1,tem(1)-1,tem(1)-1/)
  ;   ;     vertical = (/tem(0),tem(0),tem(0)+1,tem(0)-1/)
  ;   ;     plt_upper = gsn_add_polyline(wks,plot,upper(:1),upper(2:),True)
  ;   ;     plt_lower = gsn_add_polyline(wks, plot,lower(:1),lower(2:0),True)
  ;   ;     plt_ver = gsn_add_polyline(wks, plot, vertical(:1),vertical(2:),True)
  ;   end if
  ; end if
end

undef("plot_ts") ; FX| plot_ts
  function plot_ts (wks,ts[*],opt)
  local rts,res_lines,plot,res_text
  begin
  tmLabelFontHeightF = get_res_value_keep(opt,"tmLabelFontHeightF",0.02)
  rts = True
    ; rts@xyCurveDrawOrder = "postdraw"
    rts@tmYROn = False
    rts@tmXTOn = False
    rts@gsnDraw = True
    rts@gsnFrame = True
    rts@vpYF = 0.8
    rts@vpXF = 0.13
    rts@vpWidthF = 0.82
    rts@vpHeightF = 0.35
    rts@vpClipOn = False
    ; rts@xyDashPatterns = (/0.,0.,0./)      ; make all lines solid

    rts@tmYLLabelDeltaF             = -0.5
    rts@tmXBLabelDeltaF             = -0.5
    rts@tmXBMajorLengthF            = 0.01
    rts@tmXBMinorOn                 = False
    rts@tmXBMajorOutwardLengthF     = 0.01
    rts@tmYLMajorOutwardLengthF     = 0.01
    rts@tmYLMajorLengthF            = 0.01
    rts@tmBorderThicknessF = 5
    rts@xyMarkerSizeF = 10.
    rts@xyLineColor = "tomato"
    rts@gsnLeftStringOrthogonalPosF = 0.05
    ; rts@tmYLTickSpacingF = 1.
    rts@tmXBLabelFontHeightF         = tmLabelFontHeightF
    rts@tmYLLabelFontHeightF = tmLabelFontHeightF
  exclude = (/"cn","lb","Scale","preyear","gsnStringBold","tmLabelFontHeightF","vc","gsnCorner","pm","gsLine","pm"/)
  copy_VarAtts_match(opt,rts,res_plot,exclude)
  minmax = get_res_value_keep(opt,"minmax",(/ toint(min(ts))-1, toint(max(ts))+1/))
  extend = get_res_value_keep(opt,"extend",1)
  rts@trYMinF                     = minmax(0)      ; min value on x-axis
  rts@trYMaxF                     = minmax(1)
  rts@trXMinF = get_res_value_keep(opt,"trXMinF",min(ts&year)-extend)
  rts@trXMaxF = get_res_value_keep(opt,"trXMaxF", max(ts&year)+extend)
  rts@tmXBMajorThicknessF = rts@tmBorderThicknessF
  rts@tmYLMajorThicknessF = rts@tmBorderThicknessF
  rts@tmYLMode                     = "Explicit"
  rts@tmYLValues = get_res_value_keep(opt,"tmYLValues",fspan(minmax(0),minmax(1),5))
  format = get_res_value_keep(opt,"tmYLFormat","%0.1f")
  rts@tmYLLabels := sprintf(format,rts@tmYLValues)
  delete(rts@tmYLFormat)
  if(isatt(rts, "tmXBValues"))
    rts@tmXBMode = "Explicit"
    rts@tmXBLabels = get_res_value_keep(rts,"tmXBLabels",rts@tmXBValues)
  end if
  if(isatt(rts,"tmXBTickSpacingF"))then
    rts@tmXBMode = "Manual"
  end if
  nyear = dimsizes(ts&year)

  ; rts@xyDashPatterns              = (/0.,0.,0./)      ; make all lines solid
  ; if(rts@tmXBMode .eq. "Explicit")
  ;   rts@tmXBLabels = opt@tmXBLabels
  ;   rts@tmXBValues = ispan(min(ts&year),max(ts&year+2),rts@tmXBTickSpacingF)
  ; end if

  if(rts@tmYROn)
    if(isatt(opt, "tmYRValues"))then
      rts@tmYUseLeft = False
      rts@tmYRLabelsOn = True
      rts@tmYRMode = "Explicit"
    end if
    rts = get_res_eq(opt,"tmYR")
    ; rts@tmYRMajorOutwardLengthF     = 0.01
    ; rts@tmYRMajorLengthF            = 0.01
    ; rts@tmYRMajorThicknessF = rts@tmBorderThicknessF
    rts@tmYUseLeft = False
    rts@tmYRMinorOn = False
    if(isatt(opt, "tmYRLabelDeltaF"))then
      rts@tmYRLabelDeltaF = opt@tmYRLabelDeltaF
    end if
    ; rts@tmyrm
    ; rts@tmYRMode = "Explicit"
    rts@tmYRLabelFontColor = get_res_value_keep(opt,"tmYRLabelFontColor","black")
    ; rts@tmYRLabels = sprintf("%0.1f", get_res_value_keep(opt,"tmYRLabels",rts@tmYRValues))
    ; rts@tmYRLabelsOn = True
    ; rts@tmYRLabelFontHeightF         = get_res_value_keep(opt, "tmYRLabelFontHeightF",rts@tmYLLabelFontHeightF)
    ; rts@tmYRValues = get_res_value_keep(opt,"tmYRValues",ispan(-10,10,2)/10.)
    rts@tmYRMajorLineColor = get_res_value_keep(opt, "tmYRMajorLineColor", rts@tmYRLabelFontColor)
  end if
  ; printVarSummary(rts)
  rts_rm                           = rts
    rts@tiXAxisOn = isatt(opt,"tiXAxisString")
    if(rts@tiXAxisOn)
      rts = get_res_eq(opt,"tiXAxis")
      ; rts@tiXAxisString = get_res_value_keep(opt,"tiXAxisString","")
      ; rts@tiXAxisOffsetYF = get_res_value_keep(opt,"tiXAxisOffsetYF",0.)
      rts@tiXAxisFontHeightF = get_res_value_keep(opt,"tiXAxisFontHeightF",0.03)
    end if

    rts@tiYAxisOn = isatt(opt,"tiYAxisString")
    if(rts@tiYAxisOn)
      rts = get_res_eq(opt,"tiYAxis")
      ; print(rts@tiYAxisString)
      ; rts@tiYAxisString = get_res_value_keep(opt,"tiYAxisString","")
      ; rts@tiYAxisOffsetYF = get_res_value_keep(opt,"tiYAxisOffsetYF",0.)
      rts@tiYAxisFontHeightF = get_res_value_keep(opt,"tiYAxisFontHeightF",0.03)
    end if
    rts@gsnXYBarChartBarWidth        = get_res_value_keep(opt, "gsnXYBarChartBarWidth",0.6)
    rts@gsnStringFontHeightF         = get_res_value_keep(opt, "gsnStringFontHeightF",0.04)
    rts@gsnStringFont = where(get_res_value_keep(opt,"gsnStringBold",False),22,21)



    rts@tmYLMinorOn                  = False
    rts@tmYLLabelsOn                 = get_res_value_keep(opt,"tmYLLabelsOn",True)

    ; rts@gsnLeftStringParallelPosF = get_res_value_keep(opt,"gsnLeftStringParallelPosF",0)
    ; rts@gsnRightStringOrthogonalPosF = get_res_value_keep(opt,"gsnRightStringOrthogonalPosF",0.06)
    ; rts@xyLineColors                 = (/"tomato","forest green","forest green"/) ; colors chosen
    ; rts@xyMarkLineModes              = get_res_value_keep(opt,"xyMarkLineModes", (/"Lines","MarkLines","Lines"/))
    ; rts@xyMarkers                    = (/16,16,16,16/)
    ; rts@xyMarkerColors               = rts@xyLineColors
      if(get_res_value_keep(opt,"runcor",False))
        rts@tmXBMode   = "Explicit"
        rts@tmXBValues = opt@tmXBValues
        rts@tmXBLabels = opt@tmXBLabels
      end if
      if(isatt(opt, "Yref")) 
        rts@gsnYRefLine             = opt@Yref
        rts@gsnYRefLineDashPatterns = new(dimsizes(opt@Yref),integer)
        rts@gsnYRefLineDashPatterns = where(opt@Yref .eq. 0, 0, 1)
        rts@gsnYRefLineColors       = where(opt@Yref .eq. 0, "black", "dark slate gray")
        rts@gsnYRefLineThicknesses  = rts@tmBorderThicknessF
      else 
        rts@gsnYRefLine      = 0
        rts@gsnYRefLineThicknessF  = rts@tmBorderThicknessF
        rts@gsnYRefLineDashPatterns = 0
        rts@gsnYRefLineColor = 1
      end if

          ; rts@gsnYRefLine        =(/-opt@Yref,0.0,opt@Yref/);where(isatt(opt, "Yref"), opt@Yref, 0);
      ; rts@gsnYRefLineDashPatterns=(/1,0,1/)    ; line thicknesses 
      rts@gsnXYBarChart = get_res_value_keep(opt,"gsnXYBarChart",True)
      rts@tmYLLabelsOn = get_res_value_keep(opt,"tmYLLabelsOn",True)
      rts@xyLineOpacities = (/1.,1,1/)
    if(rts@gsnXYBarChart)
      rts@gsnAboveYRefLineColor = get_res_value_keep(opt,"gsnAboveYRefLineColor", "black")           ; above ref line fill red
      rts@gsnBelowYRefLineColor = get_res_value_keep(opt,"gsnBelowYRefLineColor", "black")
      ; rts@xyLineColors          := get_res_value_keep(opt,"xyLineColors", (/"black","black","black"/))
      rts@xyLineOpacityF = 0
      rts@xyMarkLineModes       := (/"Lines","Lines","Lines"/)
      rts@xyLineThicknesses     := (/0.1,0.1,1/)      ; line thicknesses
      ; rts@xyLineColor = "black"
      print(rts)
      plot                      = gsn_csm_xy(wks,ts&year,ts,rts)
      ; if(dimsizes(ts1) .ne. 1)
      ;   rts@gsnXYBarChart = False
      ;   rts@xyLineColors       = (/"tomato","forest green","forest green"/) ; colors chosen
      ;   rts@xyMarkLineModes=(/"MarkLines","MarkLines","Lines"/)
      ;   rts@xyLineThicknesses  = (/5,5,5/)
      ;   rts@xyMarkers= (/16,16,16,16/)
      ;   plt = unique_string("xy")
      ;   plot@$plt$ = gsn_csm_xy(wks,ts1&year,ts1,rts)
      ;   overlay(plot, plot@$plt$)
      ;   ; draw(plot)
      ;   ; frame(wks)
      ; end if
    else
      ; if(dimsizes(ts1) .eq. 1)
      ; printVarSummary(opt)

      if(get_res_value_keep(opt,"shading",False))
        rts@gsnAboveYRefLineColor = "tomato"
        ; rts@gsnAboveYRefLineColor := "#f0534e"
        ; rts@gsnBelowYRefLineColor = "#555aa7"
        rts@gsnBelowYRefLineColor = "forest green"
      end if
      if(dimsizes(dimsizes(ts)) .eq. 1)

        rts@xyLineThicknessF = get_res_value_keep(opt,"xyLineThicknessF",10)
        ; rts@xyMarkLineMode = "MarkLines"
        rts@xyMarkLineModes(0) = get_res_value_keep(opt,"xyMarkLineMode", "lines")
      else
        rts@xyLineColors          := get_res_value_keep(opt,"xyLineColors", (/"tomato","forest green","forest green"/))
        ; rts@xyLineColors                 = (/"tomato","forest green","forest green"/) ; colors chosen
        rts@xyLineThicknesses = get_res_value_keep(opt,"xyLineThicknesses",(/10.,1,1/) )
      end if
      ; plot = gsn_csm_xy(wks,ts&year,ts,rts)
      plot = gsn_csm_xy(wks,ts&year,ts,rts)
        ; else
        ; plot = gsn_csm_xy(wks,ts0&year,(/ts0,ts1/),rts)
        ; draw(plot)
        ; frame(wks)
      ; end if
    end if
    if(isatt(opt,"gsnCornerString"))
      corner = opt@gsnCornerString
      copy_VarAtts_eq(opt,corner,"gsnCorner")
      ; res_text = get_res_eq(opt,"gsnCorner")
      add_CornerString(plot,corner)
    end if

    ; if(isatt(opt,"name"))
    ;   str0 = unique_string("text")
    ;   res_text                    = True                  ; text mods desired
    ;   res_text@txFontHeightF      = get_res_value_keep(opt,"txFontHeightF",0.02)            ; change text size
    ;   res_text@txFontThicknessF   = 50
    ;   res_text@txJust             = "CenterLeft"          ; text justification
    ;   res_text@txFontColor        = get_res_value_keep(opt,"txFontColor",rts@xyLineColor)
    ;   plot@$str0$ = gsn_add_text(wks,plot,opt@name,opt@LegendPos(0),opt@LegendPos(1),res_text);
    ; end if
    if(isatt(opt,"name"))
      str = unique_string("text")
      ; print(str)
      res_text                    = True                  ; text mods desired
      res_text@txFontHeightF      = 0.02            ; change text size
      res_text@txFontThicknessF   = 50
      res_text@txJust             = "CenterLeft"          ; text justification
      res_text@txFontColor        = rts@xyLineColor
      copy_VarAtts_match(opt,res_text,res_plot,exclude)
      plot@$str$ = gsn_add_text(wks,plot,opt@name,opt@LegendPos(0),opt@LegendPos(1),res_text);
    end if
    if(isatt(opt,"LinePos"))
      ; print(str1)
      str1 = unique_string("polyline")
      res_lines                   = True                  ; polyline mods desired
      res_lines@gsLineDashPattern = 0.                    ; solid line
      res_lines@gsLineThicknessF  = 10.                    ; line thicker
      res_lines@gsLineColor       = rts@xyLineColor
      plot@$str1$ = gsn_add_polyline(wks,plot,opt@LinePos(:1),opt@LinePos(2:),res_lines);
    end if

  return(plot)
  end

undef("add_ts") ; FX| add_ts
procedure add_ts (plotid:graphic,ts,opt)
local tem_wks,rts,plot,str,res_text
begin
    tem_wks = NhlGetParentWorkstation(plotid)
    rts = True
    rts@xyLineColor = "tomato"
    rts@xyLineThicknessF = 10
    rts@gsnXYBarChart           = False
    rts@xyMarkLineMode = "Lines"
    rts@xyMarkers               = 16
    rts@xyMarkerSizeF := 0.022
    rts@trXMinF = 1978
    rts@trXMaxF = 2019
    rts@gsnFrame = False
    rts@gsnDraw = False
    rts@xyCurveDrawOrder = "postdraw"
    ; rts@gsnYRefLine = 0.1 ; 写了也画不出来
    rts@xyDashPattern = get_res_value_keep(rts,"xyDashPattern", 0)
    exclude = (/"cn","lb","Scale","preyear","gsnStringBold","tmLabelFontHeightF","vc","gsnCorner","pm","tmYLFormat"/)
    copy_VarAtts_match(opt,rts,res_plot,exclude)
    rts@gsnRightStringFontColor = rts@xyLineColor
    rts@xyMarkerColor           = rts@xyLineColor
    rts@gsnLeftString           = ""
    rts@gsnRightString          = ""
    plot = gsn_csm_xy(tem_wks,ts&year,ts,rts)
    if(isatt(opt,"name"))
      str = unique_string("text")
      res_text                    = True                  ; text mods desired
      res_text@txFontHeightF      = 0.02            ; change text size
      res_text@txFontThicknessF   = 50
      res_text@txJust             = "CenterLeft"          ; text justification
      res_text@txFontColor        = rts@xyLineColor
      copy_VarAtts_match(opt,res_text,res_plot,exclude)
      plotid@$str$ = gsn_add_text(tem_wks,plotid,opt@name,opt@LegendPos(0),opt@LegendPos(1),res_text);
    end if
    overlay(plotid,plot)
  end

undef("rec95Interval")
function rec95Interval(x,y,rec,Sxy,x0)
local df,Syxy,t95,upper,lower
begin 
  xMean = avg(x)
  df = dimsizes(x)-2
  Syxy = sqrt(Sxy)*sqrt(1./dimsizes(x)+((x0-xMean)^2)/sum((x-xMean)^2))
  t95 = cdft_t(0.975,df)
  ; t95 = 1
  upper = rec*x0+rec@yintercept+t95*Syxy
  lower = rec*x0+rec@yintercept-t95*Syxy
return (/upper,lower/)
end

undef("add_regLine")
procedure add_regLine(plotid,x,y,opt)
local tem_wks, rec,line_x, line_y, res_line,str
begin
  res_line = get_att_eq(opt,"gs")
  tem_wks = NhlGetParentWorkstation(plotid)
  rec = regCoef(x, y)
  line_x = (/min(x),max(x)/)
  line_y = rec*line_x+rec@yintercept
  str = unique_string("regline")
  plotid@$str$ = gsn_add_polyline(tem_wks,plotid,line_x,line_y,res_line)
end

undef("add_interval")
procedure add_interval(plotid,x,y,opt)
local tem_wks,rec,exclude,include,line_x,line_y,res_line,str,yfit,Sxy,xSmooth,upperAndLower,upper,lower,dim,ul,x2,rfill
begin
  tem_wks = NhlGetParentWorkstation(plotid)
  res_line = True
    res_line@gsLineDashPattern = 16
    res_line@gsLineThicknessF = 10.
    ; res_line@gsLineOpacityF = 0.7
  exclude := "gsn"
  include := (/"xy","tx","gs"/)
  copy_VarAtts_match(opt,res_line,include,exclude)
  copy_VarAtts_match(y,res_line,include,exclude)
    rec = regCoef(x, y)
    line_x = (/min(x),max(x)/)
    line_y = rec*line_x+rec@yintercept
    ; yl = rec*x+rec@yintercept
    res_line@tfPolyDrawOrder = "predraw"

    ; res_line@gsMarkLineMode = "Lines"
    ; res_line@gsDashPattern = 16
    str = unique_string("regline")
    plotid@$str$ = gsn_add_polyline(tem_wks,plotid,line_x,line_y,res_line)
    yfit = rec*x+rec@yintercept
    Sxy = sqrt((sum((y-yfit)^2))/(dimsizes(x)-2))
    ; Sxy = stddev(x)
    xmin = get_res_value_keep(opt, "trXMinF", min(x))
    xmax = get_res_value_keep(opt, "trXMaxF", max(x))
    xSort = x
    qsort(xSort)
    xSmooth = xSort
    upperAndLower = rec95Interval(x,y,rec,Sxy,xSmooth)
    upper = upperAndLower(0,:)
    lower = upperAndLower(1,:)
    dim = dimsizes(upper)
    ul = new(dim*2,float)
    ul(:dim-1) = upper
    ul(dim:dim*2-1) = lower(::-1)
    x2 = ul
    x2(:dim-1) = xSmooth
    x2(dim:dim*2-1) = xSmooth(::-1)
    str = unique_string("interval")
    rfill := True
      rfill@gsFillColor = get_res_value_keep(opt, "gsFillColor", "grey")
      rfill@gsFillOpacityF = get_res_value_keep(opt, "gsFillOpacityF", 0.1)
    plotid@$str$ = gsn_add_polygon(tem_wks, plotid, x2, ul, rfill)
end

undef("scatter")
function scatter (wks,x,y,opt)
local y0,y1,simple_mode,option,include,plot,ploto,res,tem,corner,text,res_YR,res_line,rec,line_x,line_y,str,res_legend,i,list_size
begin
  if(typeof(y) .eq. "list")
    y0 = y[0]
    list_size = ListCount(y)
    simple_mode = (list_size .eq. 1)
  else
    y0 = y
    simple_mode = True
  end if
  option = True
    option@opRegLine = False
    option@opXMinMax = (/-2,2./)
    option@opYMinMax = (/-2,2./)
  include := "op"
  copy_VarAtts_match(opt,option,include,"")
  copy_VarAtts_match(y0,option,include,"")
  res = True
    res@gsnDraw = True
    res@gsnFrame = True
    res@tmYROn = False
    res@tmXTOn = False
    res@tmXBMinorOn = False
    res@tmYLMinorOn = False
    res@tmBorderThicknessF = 5
    res@gsnYRefLine = 0.
    res@gsnXRefLine = 0.
    res@trXMaxF = option@opXMinMax(1)
    res@trXMinF = option@opXMinMax(0)
    res@trYMaxF = option@opYMinMax(1)
    res@trYMinF = option@opYMinMax(0)
    res@tmXBMajorLengthF = 0.01
    res@tmXBMajorOutwardLengthF = 0.01
    res@tmYLMajorLengthF = 0.01
    res@tmYLMajorOutwardLengthF = 0.01
    res@tmXBLabelDeltaF = -0.3
    res@tmYLLabelDeltaF = -0.3
    res@xyMarkLineMode = "markers"
    res@xyMarkerColor = "tomato"
    res@xyMarkers = 16
  exclude := (/"gsLine","tiYRAxis","gsnCorner"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  tem = res
  copy_VarAtts_match(y0,res,res_plot,exclude)
  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF
  if(isatt(res,"tmXBTickSpacingF") .and. .not. isatt(res, "tmXBMode"))then
    res@tmXBMode = "Manual"
  end if
  if(isatt(res,"tmYLTickSpacingF"))then
    res@tmYLMode = "Manual"
  end if
  if(isatt(res, "xyMarkers") .and. dimsizes(res@xyMarkers) .gt. 1)then
    plot = gsn_csm_xy(wks,transpose((/x,x/)),transpose((/y0,y0/)),res)
  else
    plot = gsn_csm_xy(wks,x,y0,res)
  end if
  delete([/res@gsnYRefLine,res@gsnXRefLine/])
  if(isatt(opt,"gsnCornerString"))
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if
  if(isatt(opt,"tiYRAxisString"))
    text = opt@tiYRAxisString
    res_YR = True
    if(.not. isatt(opt,"tiYRAxisStringFontHeightF"))
      res_YR@tiYRAxisStringFontHeight = res@tiYAxisFontHeightF
    end if
    copy_VarAtts_eq(opt,res_YR,"tiYRAxis")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_YRAxisString(plot,text,res_YR)
  end if  

  res_line = True
    res_line@gsLineDashPattern = 16
    res_line@gsLineThicknessF = 10.
    res_line@gsLineColor = res@xyMarkerColor
    res_line@gsLineOpacityF = 0.7
  exclude := "gsn"
  include := (/"xy","tx","gs"/)
  copy_VarAtts_match(opt,res_line,include,exclude)
  copy_VarAtts_match(y0,res_line,include,exclude)

  if(option@opRegLine)
    rec = regCoef(x, y0)
    line_x = (/min(x),max(x)/)
    line_y = rec*line_x+rec@yintercept
    ; yl = rec*x+rec@yintercept
    res_line@tfPolyDrawOrder = "predraw"

    ; res_line@gsMarkLineMode = "Lines"
    ; res_line@gsDashPattern = 16
    str = unique_string("regline")
    plot@$str$ = gsn_add_polyline(wks,plot,line_x,line_y,res_line)
    yfit = rec*x+rec@yintercept
    Sxy = sqrt((sum((y-yfit)^2))/(dimsizes(x)-2))
    ; Sxy = stddev(x)
    xSmooth = x
    qsort(xSmooth)
    ; xSmooth = fspan(res@trXMinF, res@trXMaxF, 20)
    upperAndLower = rec95Interval(x,y0,rec,Sxy,xSmooth)
    upper = upperAndLower(0,:)
    lower = upperAndLower(1,:)
    dim = dimsizes(upper)
    ul = new(dim*2,float)
    ul(:dim-1) = upper
    ul(dim:dim*2-1) = lower(::-1)
    x2 = ul
    x2(:dim-1) = xSmooth
    x2(dim:dim*2-1) = xSmooth(::-1)
    str = unique_string("interval")
    rfill := True
      rfill@gsFillColor = "grey"
      rfill@gsFillOpacityF = 0.11
    plot@$str$ = gsn_add_polygon(wks, plot, x2, ul, rfill)
    ; str = unique_string("upper")
    ; plot@$str$ = gsn_add_polyline(wks,plot,xSmooth,upper,res_line)
    ; str = unique_string("lower")
    ; plot@$str$ = gsn_add_polyline(wks,plot,xSmooth,lower,res_line)
  end if
  if(isatt(option,"opName") .and. isatt(option,"opPos"))
    res_legend = True
    res_legend@gsMarkerColor = y0@xyMarkerColor
    res_legend@gsMarkerIndex = get_res_value_keep(y0,"xyMarkers",get_res_value_keep(opt,"xyMarkers",16))
    res_legend@gsMarkerSizeF = get_res_value_keep(y0,"xyMarkerSizeF",res@xyMarkerSizeF)
    res_legend@gsMarkerThicknessF = res_line@xyMarkerThicknessF
    exclude := "gsn"
    include := (/"op","gs","tx"/)
    copy_VarAtts_match(opt,res_legend,include,exclude)
    copy_VarAtts_match(y0,res_legend,include,exclude)
    add_legend(plot,y0@opName,y0@opPos(0),y0@opPos(1),res_legend)
  end if
  if(.not. simple_mode)
    do i = 1, list_size-1
      res = tem
        res@tmXBLabelsOn = False
        res@tmYLOn = False
        res@tmYROn = False
        res@tmXBMinorOn = False
      y1 := y[i]
      exclude := (/"ti","tm","gs","op","gsnXRefLine","gsnYRefLine"/)
      copy_VarAtts_match(opt,res,include,exclude)
      copy_VarAtts_match(y1,res,res_plot,exclude)
      delete([/res@gsnXRefLine,res@gsnYRefLine/])
      ploto = gsn_csm_xy(wks,x,y1,res)
      overlay(plot,ploto)

      option@opRegLine = False
      copy_VarAtts_match(opt,option,"op","")
      copy_VarAtts_match(y1,option,"op","")

      if(option@opRegLine)
        exclude := "gsn"
        include := (/"op","gs","tx"/)
        res_line@gsLineDashPattern = 16
        res_line@gsLineThicknessF = 10.
        res_line@gsLineColor = res@xyMarkerColor
        copy_VarAtts_match(opt,res_line,include,exclude)
        copy_VarAtts_match(y1,res_line,include,exclude)
        rec = regCoef(x, y1)
        ; yl = rec*x+rec@yintercept
        line_x = (/min(x),max(x)/)
        line_y = rec*line_x+rec@yintercept
        ; res_line@xyLineThicknessF = 10.
        ; res_line@xyMarkLineMode = "Lines"
        ; res_line@xyDashPattern = 16
        ; res_line@xyLineColor = res@xyMarkerColor
        str = unique_string("regline")
        plot@$str$ = gsn_add_polyline(wks,plot,line_x,line_y,res_line)
      end if
      if(isatt(option,"opName") .and. isatt(option,"opPos"))
        res_legend = True
        res_legend@gsMarkerColor = y1@xyMarkerColor
        res_legend@gsMarkerIndex = get_res_value_keep(y1,"xyMarkers",get_res_value_keep(opt,"xyMarkers",16))
        res_legend@gsMarkerSizeF = get_res_value_keep(y1,"xyMarkerSizeF",res@xyMarkerSizeF)
        res_legend@gsMarkerThicknessF = res_line@xyMarkerThicknessF
        exclude := "gsn"
        include := (/"op","gs","tx"/)
        copy_VarAtts_match(opt,res_legend,include,exclude)
        copy_VarAtts_match(y1,res_legend,include,exclude)
        add_legend(plot,y1@opName,y1@opPos(0),y1@opPos(1),res_legend)
      end if
    end do
  end if
  return(plot)
end

undef("add_scatter")
procedure add_scatter (plotid,x,y,opt)
local tem_wks,y0,y1,simple_mode,option,include,plot,ploto,res,tem,corner,text,res_YR,res_line,rec,line_x,line_y,str,res_legend,i,list_size
begin
  tem_wks := NhlGetParentWorkstation(plotid)
  if(typeof(y) .eq. "list")
    y0 = y[0]
    list_size = ListCount(y)
    simple_mode = (list_size .eq. 1)
  else
    y0 = y
    simple_mode = True
  end if
  option = True
    option@opRegLine = False
    option@opXMinMax = (/-2,2./)
    option@opYMinMax = (/-2,2./)
  include := "op"
  copy_VarAtts_match(opt,option,include,"")
  copy_VarAtts_match(y0,option,include,"")
  res = True
    res@gsnDraw = True
    res@gsnFrame = True
    res@tmYROn = False
    res@tmXTOn = False
    res@tmXBMinorOn = False
    res@tmYLMinorOn = False
    res@tmBorderThicknessF = 5
    res@gsnYRefLine = 0.
    res@gsnXRefLine = 0.
    res@trXMaxF = option@opXMinMax(1)
    res@trXMinF = option@opXMinMax(0)
    res@trYMaxF = option@opYMinMax(1)
    res@trYMinF = option@opYMinMax(0)
    res@tmXBMajorLengthF = 0.01
    res@tmXBMajorOutwardLengthF = 0.01
    res@tmYLMajorLengthF = 0.01
    res@tmYLMajorOutwardLengthF = 0.01
    res@tmXBLabelDeltaF = -0.3
    res@tmYLLabelDeltaF = -0.3
    res@xyMarkLineMode = "markers"
    res@xyMarkerColor = "tomato"
    res@xyMarkers = 16
  exclude := (/"gsLine","tiYRAxis","gsnCorner"/)
  copy_VarAtts_match(opt,res,res_plot,exclude)
  tem = res
  copy_VarAtts_match(y0,res,res_plot,exclude)
  res@tmXBMajorThicknessF = res@tmBorderThicknessF
  res@tmYLMajorThicknessF = res@tmBorderThicknessF
  res@gsnLeftString = ""
  res@gsnRightString = ""
  if(isatt(res,"tmXBTickSpacingF") .and. .not. isatt(res, "tmXBMode"))then
    res@tmXBMode = "Manual"
  end if
  if(isatt(res,"tmYLTickSpacingF"))then
    res@tmYLMode = "Manual"
  end if
  if(isatt(res, "xyMarkers") .and. dimsizes(res@xyMarkers) .gt. 1)then
    plot = gsn_csm_xy(tem_wks,transpose((/x,x/)),transpose((/y0,y0/)),res)
  else
    plot = gsn_csm_xy(tem_wks,x,y0,res)
  end if
  delete([/res@gsnYRefLine,res@gsnXRefLine/])
  if(isatt(opt,"gsnCornerString"))
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if
  if(isatt(opt,"tiYRAxisString"))
    text = opt@tiYRAxisString
    res_YR = True
    if(.not. isatt(opt,"tiYRAxisStringFontHeightF"))
      res_YR@tiYRAxisStringFontHeight = res@tiYAxisFontHeightF
    end if
    copy_VarAtts_eq(opt,res_YR,"tiYRAxis")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_YRAxisString(plot,text,res_YR)
  end if  

  res_line = True
    res_line@gsLineDashPattern = 16
    res_line@gsLineThicknessF = 10.
    res_line@gsLineColor = res@xyMarkerColor
    res_line@gsLineOpacityF = 0.7
  exclude := "gsn"
  include := (/"xy","tx","gs"/)
  copy_VarAtts_match(opt,res_line,include,exclude)
  copy_VarAtts_match(y0,res_line,include,exclude)

  if(option@opRegLine)
    rec = regCoef(x, y0)
    line_x = (/min(x),max(x)/)
    line_y = rec*line_x+rec@yintercept
    ; yl = rec*x+rec@yintercept
    res_line@tfPolyDrawOrder = "predraw"

    ; res_line@gsMarkLineMode = "Lines"
    ; res_line@gsDashPattern = 16
    str = unique_string("regline")
    plotid@$str$ = gsn_add_polyline(tem_wks,plot,line_x,line_y,res_line)
    yfit = rec*x+rec@yintercept
    Sxy = sqrt((sum((y-yfit)^2))/(dimsizes(x)-2))
    ; Sxy = stddev(x)
    xSmooth = x
    qsort(xSmooth)
    ; xSmooth = fspan(res@trXMinF, res@trXMaxF, 20)
    upperAndLower = rec95Interval(x,y0,rec,Sxy,xSmooth)
    upper = upperAndLower(0,:)
    lower = upperAndLower(1,:)
    dim = dimsizes(upper)
    ul = new(dim*2,float)
    ul(:dim-1) = upper
    ul(dim:dim*2-1) = lower(::-1)
    x2 = ul
    x2(:dim-1) = xSmooth
    x2(dim:dim*2-1) = xSmooth(::-1)
    str = unique_string("interval")
    rfill := True
      rfill@gsFillColor = "grey"
      rfill@gsFillOpacityF = 0.2
    plotid@$str$ = gsn_add_polygon(tem_wks, plot, x2, ul, rfill)
    ; str = unique_string("upper")
    ; plot@$str$ = gsn_add_polyline(wks,plot,xSmooth,upper,res_line)
    ; str = unique_string("lower")
    ; plot@$str$ = gsn_add_polyline(wks,plot,xSmooth,lower,res_line)
  end if
  if(isatt(option,"opName") .and. isatt(option,"opPos"))
    res_legend = True
    res_legend@gsMarkerColor = y0@xyMarkerColor
    res_legend@gsMarkerIndex = get_res_value_keep(y0,"xyMarkers",get_res_value_keep(opt,"xyMarkers",16))
    res_legend@gsMarkerSizeF = get_res_value_keep(y0,"xyMarkerSizeF",res@xyMarkerSizeF)
    res_legend@gsMarkerThicknessF = res_line@xyMarkerThicknessF
    exclude := "gsn"
    include := (/"op","gs","tx"/)
    copy_VarAtts_match(opt,res_legend,include,exclude)
    copy_VarAtts_match(y0,res_legend,include,exclude)
    add_legend(plot,y0@opName,y0@opPos(0),y0@opPos(1),res_legend)
  end if
  if(.not. simple_mode)
    do i = 1, list_size-1
      res = tem
        res@tmXBLabelsOn = False
        res@tmYLOn = False
        res@tmYROn = False
        res@tmXBMinorOn = False
      y1 := y[i]
      exclude := (/"ti","tm","gs","op","gsnXRefLine","gsnYRefLine"/)
      copy_VarAtts_match(opt,res,include,exclude)
      copy_VarAtts_match(y1,res,res_plot,exclude)
      delete([/res@gsnXRefLine,res@gsnYRefLine/])
      ploto = gsn_csm_xy(tem_wks,x,y1,res)
      overlay(plot,ploto)

      option@opRegLine = False
      copy_VarAtts_match(opt,option,"op","")
      copy_VarAtts_match(y1,option,"op","")

      if(option@opRegLine)
        exclude := "gsn"
        include := (/"op","gs","tx"/)
        res_line@gsLineDashPattern = 16
        res_line@gsLineThicknessF = 10.
        res_line@gsLineColor = res@xyMarkerColor
        copy_VarAtts_match(opt,res_line,include,exclude)
        copy_VarAtts_match(y1,res_line,include,exclude)
        rec = regCoef(x, y1)
        ; yl = rec*x+rec@yintercept
        line_x = (/min(x),max(x)/)
        line_y = rec*line_x+rec@yintercept
        ; res_line@xyLineThicknessF = 10.
        ; res_line@xyMarkLineMode = "Lines"
        ; res_line@xyDashPattern = 16
        ; res_line@xyLineColor = res@xyMarkerColor
        str = unique_string("regline")
        plotid@$str$ = gsn_add_polyline(tem_wks,plot,line_x,line_y,res_line)
      end if
      if(isatt(option,"opName") .and. isatt(option,"opPos"))
        res_legend = True
        res_legend@gsMarkerColor = y1@xyMarkerColor
        res_legend@gsMarkerIndex = get_res_value_keep(y1,"xyMarkers",get_res_value_keep(opt,"xyMarkers",16))
        res_legend@gsMarkerSizeF = get_res_value_keep(y1,"xyMarkerSizeF",res@xyMarkerSizeF)
        res_legend@gsMarkerThicknessF = res_line@xyMarkerThicknessF
        exclude := "gsn"
        include := (/"op","gs","tx"/)
        copy_VarAtts_match(opt,res_legend,include,exclude)
        copy_VarAtts_match(y1,res_legend,include,exclude)
        add_legend(plot,y1@opName,y1@opPos(0),y1@opPos(1),res_legend)
      end if
    end do
  end if
  overlay(plotid, plot)
  ; return(plot)
end

undef("gsn_panel_return")
function gsn_panel_return (wks:graphic,plot[*]:graphic,dims[*]:integer,\
                          resources:logical)
local res, nrows, ncols, ddims, is_row_spec, row_spec, npanels, nplots, \
      perim_on,i,tem
begin

  res = get_resources(resources)           ; Make copy of resources
;
; First check if paneling is to be specified by (#rows x #columns) or
; by #columns per row.  The default is rows x columns, unless 
; resource gsnPanelRowSpec is set to True, in which case "dims"
; will represent number of plots per row.
; 
  is_row_spec = get_res_value(res,"gsnPanelRowSpec",False)
;
; Check to see if we have enough plots to fit panels, and vice versa.
;
  ddims = dimsizes(dims)
  if(is_row_spec)
    row_spec = dims
    npanels = 0
    nrows = ddims
    ncols = max(row_spec)
    do i=0,nrows-1
      if(row_spec(i).lt.0)
        print("gsn_panel: Error: you have specified a negative value for the number of plots in a row.")
        exit
      end if
      npanels = npanels + row_spec(i)
    end do
  else
    if(ddims.ne.2)
      print("gsn_panel: Error: for the third argument of gsn_panel, you must either specify # rows by # columns or set gsnPanelRowSpec to True and set the number of plots per row.")
      exit
    end if
    nrows    = dims(0)
    ncols    = dims(1)
    npanels  = nrows * ncols
    row_spec = new(nrows,integer)
    row_spec = ncols
  end if
 
  nplots  = dimsizes(plot)      ; Total number of plots.

  if(nplots.gt.npanels)
    print("gsn_panel: warning: you have more plots than you have panels.")
    print("Only " + npanels + " plots will be drawn.")
    nplots = npanels
  end if

;
; Check for special resources.
; 
  panel_save     = get_res_value_keep(res,"gsnPanelSave",True)
  panel_debug    = get_res_value_keep(res,"gsnPanelDebug",False)
  panel_center   = get_res_value_keep(res,"gsnPanelCenter",True)
  panel_labelbar = get_res_value_keep(res,"gsnPanelLabelBar",False)
  panel_plotid   = get_res_value_keep(res,"gsnPanelScalePlotIndex",-1)
  panel_lbarid   = get_res_value_keep(res,"gsnPanelLabelBarPlotIndex",-1)
  calldraw       = get_res_value_keep(res,"gsnDraw",True)
  callframe      = get_res_value_keep(res,"gsnFrame",True)
  xwsp_perc      = get_res_value_keep(res,"gsnPanelXWhiteSpacePercent",1.)
  ywsp_perc      = get_res_value_keep(res,"gsnPanelYWhiteSpacePercent",1.)
  draw_boxes     = get_res_value_keep(res,"gsnPanelBoxes",False)
  x_lft          = get_res_value_keep(res,"gsnPanelLeft",0.)
  x_rgt          = get_res_value_keep(res,"gsnPanelRight",1.)
  y_bot          = get_res_value_keep(res,"gsnPanelBottom",0.)
  y_top          = get_res_value_keep(res,"gsnPanelTop",1.)
  main_string    = get_res_value_keep(res,(/"gsnPanelMainString","txString"/),"")
  maxbb          = get_bb_res(res)

  lft_pnl        = isatt(res,"gsnPanelLeft")
  rgt_pnl        = isatt(res,"gsnPanelRight")
  bot_pnl        = isatt(res,"gsnPanelBottom")
  top_pnl        = isatt(res,"gsnPanelTop")


;
; Check if a main string has been specified. If so, we need to make sure
; we leave some room for it by computing y_top (if the user hasn't set
; it). Also, we have to check if the font height has been set, because
; this could affect the title position.
; 
  if(main_string.ne."") then
    main_string_on = True
    main_font_hgt  = get_res_value_keep(res,(/"gsnPanelMainFontHeightF","txFontHeightF"/),0.02)
;
; By default, we want a distance of 0.01 between top of title and the
; frame, and a distance of 0.03  between the bottom of the title (txPosYF)
; and the top of the panel box (gsnPanelTop).
;
    if(y_top.eq.1.) then
      if(isatt(res,"gsnPanelMainPosYF"))
        y_top = min((/1.,res@gsnPanelMainPosYF - 0.03/))
      elseif(isatt(res,"txPosYF"))
        y_top = min((/1.,res@txPosYF - 0.03/))
      else
        y_top = min((/1.,0.96-main_font_hgt/))
      end if
    end if
  else
    main_string_on = False
  end if
;
; Calculate number of plot objects that will actually be drawn.
; This include the panel plots, the labelbar (if any), and 
; main string (if any).
;
  nnewplots = nplots
  if(panel_labelbar) then
    is_multi_lb = isArray(panel_lbarid)
    if(is_multi_lb) then
      nnewplots = nnewplots + dimsizes(panel_lbarid)
    else
      nnewplots = nnewplots + 1
    end if
  end if
  if(main_string_on) then
    nnewplots = nnewplots + 1
  end if

  newplots = new(nnewplots,graphic)   ; Create array to save these plots
                                      ; objects.
;
; We only need to set maxbb to True if the plots are being drawn to
; a PostScript or PDF workstation, because the bounding box is already
; maximized for an NCGM/X11 window.
; 
  if(maxbb) then
    class = NhlClassName(wks)
    if(.not.any(class(0).eq.(/"psWorkstationClass", "pdfWorkstationClass", \
                              "documentWorkstationClass"/)))
      maxbb = False
    end if
    delete(class)
  end if
;
; Get some resources for the figure strings, if they exist.
;
  if(isatt(res,"gsnPanelFigureStrings"))
    is_figure_strings = True
    panel_strings = get_res_value(res,"gsnPanelFigureStrings","")      
;
; Get and set resource values for figure strings on the plots.
;
    justs = (/"bottomright", "topright", "topleft", "bottomleft"/)
    paras = (/     1.0,           1.0,      -1.0,       -1.0/)
    orths = (/     1.0,          -1.0,      -1.0,        1.0/)

    amres = get_res_eq(res,"am")
    just = str_lower(get_res_value(res,(/"gsnPanelFigureStringsJust","amJust"/),"bottomright"))
;
; Look for all resources that start with gsnPanelFigureStrings, and replace
; this with just "tx". This is what allows us to sneak in text resources
; and have them only apply to the figure strings, and not the main string.
;
    txres    = get_res_eq_replace(res,"gsnPanelFigureStrings","tx")
    perim_on = get_res_value(txres,"txPerimOn",True)
    bkgrn    = get_res_value(txres,"txBackgroundFillColor",0)
  else
    is_figure_strings = False
  end if
;
; Error check the values that the user has entered, to make sure
; they are valid. 
;  
  if(xwsp_perc.lt.0.or.xwsp_perc.ge.100.)
    print("gsn_panel: Warning: attribute gsnPanelXWhiteSpacePercent must be >= 0 and < 100.")
    print("Defaulting to 1.")
    xwsp_perc = 1.
  end if

  if(ywsp_perc.lt.0.or.ywsp_perc.ge.100.)
    print("gsn_panel: Warning: attribute gsnPanelYWhiteSpacePercent must be >= 0 and < 100.")
    print("Defaulting to 1.")
    ywsp_perc = 1.
  end if

  if(x_lft.lt.0..or.x_lft.ge.1.)
    print("gsn_panel: Warning: attribute gsnPanelLeft must be >= 0.0 and < 1.0")
    print("Defaulting to 0.")
    x_lft = 0.0
  end if

  if(x_rgt.le.0..or.x_rgt.gt.1.)
    print("gsn_panel: Warning: attribute gsnPanelRight must be > 0.0 and <= 1.0")
    print("Defaulting to 1.")
    x_rgt = 1.0
  end if

  if(y_top.le.0..or.y_top.gt.1.)
    print("gsn_panel: Warning: attribute gsnPanelTop must be > 0.0 and <= 1.0")
    print("Defaulting to 1.")
    y_top = 1.0
  end if

  if(y_bot.lt.0..or.y_bot.ge.1.)
    print("gsn_panel: Warning: attribute gsnPanelBottom must be >= 0.0 and < 1.0")
    print("Defaulting to 0.")
    y_bot = 0.0
  end if

  if(x_rgt.le.x_lft)
    print("gsn_panel: Error: attribute gsnPanelRight ("+x_rgt+") must be greater")
    print("than gsnPanelLeft ("+x_lft+").")
    exit
  end if

  if(y_top.le.y_bot)
    print("gsn_panel: Error: attribute gsnPanelTop ("+y_top+") must be greater")
    print("than gsnPanelBottom ("+y_bot+").")
    exit
  end if

;
; Get the plot object id that we will use to determine the scale factor
; for resizing all of the plots. If gsnPanelScalePlotId was set
; (panel_id), then use this. Otherwise, we will start at the first
; plot and keep going until we find a "valid" (non missing) plot.
;
; We assume all plots are the same size, so if we get the size of
; one of them, then this should represent the size of the rest
; of them. Also, count the number of non-missing plots for later.
;
  ind_nomsg = ind(.not.ismissing(plot(0:nplots-1)))
  if(all(ismissing(ind_nomsg))) then
    print("gsn_panel: Error: all of the plots passed to gsn_panel appear to be invalid")
    exit
  end if
  if(panel_plotid.ge.0.and.panel_plotid.le.(nplots-1).and. \
     .not.ismissing(plot(panel_plotid))) then
    valid_plot = panel_plotid
  else
    valid_plot = ind_nomsg(0)
  end if
;
; In NCL V6.6.0, we added a new resource, gsnPanelLabelBarPlotIndex 
; which allows you to specify which plot to base the panel labelbar
; on. If none is specified, then the first non-missing plot in the
; list will be used.
;

  bb     = NhlGetBB(plot(valid_plot))   ; Get bounding box of this plot
  top    = bb(0)
  bottom = bb(1)
  left   = bb(2)
  right  = bb(3)
  delete(bb)
  nvalid_plots = dimsizes(ind_nomsg)
  delete(ind_nomsg)

  if(panel_debug) then
    print("There are " + nvalid_plots + " valid plots out of " + nplots + " total plots")
  end if

;
; Get the type of plots we have. "plot" can be a map, in which case
; the contour, vector, streamine plot overlaid on it will be indicated
; by an attribute, for example, "plot@contour" or "plot@vector".
;
  new_plot     = get_plot_not_loglin(plot(valid_plot))


;
; Get the font height of a particular plot element, so we can
; use this for panel plot elements, like the size of the 
; common labelbar labels, the main title, etc.
;
  if(is_figure_strings.or.panel_labelbar) then
    if(new_plot@plot_type.eq."contour") then
      getvalues new_plot
        "cnInfoLabelFontHeightF" : font_height
      end getvalues
    elseif(new_plot@plot_type.eq."vector") then
      getvalues new_plot
        "vcRefAnnoFontHeightF" : font_height
      end getvalues
    elseif(new_plot@plot_type.eq."xy") then
      getvalues new_plot
        "tiXAxisFontHeightF" : font_height
      end getvalues
      font_height = 0.6*font_height
    elseif(new_plot@plot_type.eq."streamline") then
;
; There's no equivalent font height resource for streamline to 
; retrieve, so just set it here.
;
      font_height = 0.01
    else
      font_height = 0.01
    end if
;
; Use this font height for the panel figure strings, if any, unless
; the user has set gsnPanelFigureStringsFontHeightF.
;
    pfont_height = get_res_value(res,"gsnPanelFigureStringsFontHeightF",\
                                 font_height)
  end if


;
; This section calculates the scale factor needed to rescale the 
; plots so they fit on one page.  It has to account for white 
; space between each plot, and space for the labelbar and main title, 
; if any.
;
; plot_width  : total width of plot with all of its annotations
; plot_height : total height of plot with all of its annotations
; total_width : plot_width plus white space on both sides
; total_height: plot_height plus white space on top and bottom
;
  plot_width  = right - left     ; Calculate total width of plot.
  plot_height = top - bottom     ; Calculate total height of plot.

  xwsp = xwsp_perc/100. * plot_width  ; White space is a percentage of total
  ywsp = ywsp_perc/100. * plot_height ; width and height.

  total_width  = 2.*xwsp + plot_width   ; Calculate total width and height
  total_height = 2.*ywsp + plot_height  ; with white space added.
;
; If we are putting a global labelbar at the bottom (right), make 
; it 0.2x the height (width) of the plot.
;
  lbhor = True
  if(panel_labelbar) then
    lbres = get_res_eq(res,(/"lb","pmLabelBar","vp"/))  ; Get labelbar resources.
    if(check_attr_enum_value(lbres,"lbOrientation","vertical")) then
      lbhor = False
      labelbar_width = 0.20 * plot_width + 2.*xwsp
;
; Adjust height depending on whether we have one row or multiple rows.
;
      if(nplots.gt.1.and.nrows.gt.1) then
        labelbar_height  = (nrows-1) * (2.*ywsp + plot_height)
      else
        labelbar_height  = plot_height
      end if
    else         
      set_attr(lbres,"lbOrientation","Horizontal")

      labelbar_height = 0.20 * plot_height + 2.*ywsp
;
; Adjust width depending on whether we have one column or multiple 
; columns.
;
      if(nplots.gt.1.and.ncols.gt.1) then
        labelbar_width  = (ncols-1) * (2.*xwsp + plot_width)
      else
        labelbar_width  = plot_width
      end if
    end if
  else
    labelbar_height = 0.
    labelbar_width  = 0.
  end if
;
; We want:
;
;   ncols * scale * total_width  <= x_rgt - x_lft (the viewport width)
;   nrows * scale * total_height <= y_top - y_bot (the viewport height)
;   [or scale * (nrows * total_height + labelbar_height) if a labelbar
;    is being drawn]
;
; By taking the minimum of these two, we get the scale
; factor that we need to fit all plots on a page.
;
  xrange = x_rgt - x_lft
  yrange = y_top - y_bot

  if(lbhor) then
;
; Previously, we used to include xrange and yrange as part of the min
; statement. This seemed to cause problems if you set one of
; gsnPanelTop/Bottom/Right/Left however, so I removed it.
;
    row_scale = yrange/(nrows*total_height+labelbar_height)
    col_scale = xrange/(ncols*total_width)
    scale     = min((/col_scale,row_scale/))
    yrange    = yrange - scale * labelbar_height
  else
;
; See above comments.
;
    row_scale = yrange/(nrows*total_height)
    col_scale = xrange/(ncols*total_width+labelbar_width)
    scale     = min((/col_scale,row_scale/))
    xrange    = xrange - scale * labelbar_width
  end if
  new_plot_width  = scale*plot_width    ; Calculate new width
  new_plot_height = scale*plot_height   ; and height.

  xwsp = xwsp_perc/100. * new_plot_width   ; Calculate new white space.
  ywsp = ywsp_perc/100. * new_plot_height

  new_total_width  = 2.*xwsp + new_plot_width  ; Calculate new total width
  new_total_height = 2.*ywsp + new_plot_height ; and height w/white space.

  xsp = xrange - new_total_width*ncols  ; Calculate total amt of white space
  ysp = yrange - new_total_height*nrows ; left in both X and Y directions.

  getvalues plot(valid_plot)
    "vpXF"      : vpx
    "vpYF"      : vpy
    "vpWidthF"  : vpw
    "vpHeightF" : vph
  end getvalues

  dxl = scale * (vpx-left)           ; Distance from plot's left
                                     ; position to its leftmost annotation
  dxr = scale * (right-(vpx+vpw))    ; Distance from plot's right
                                     ; position to its rightmost annotation
  dyt = scale * (top-vpy)            ; Distance from plot's top
                                     ; position to its topmost annotation.
  dyb = scale * ((vpy-vph)-bottom)   ; Distance from plot's bottom
                                     ; position to its bottommost annotation.

  ypos = y_top - ywsp - dyt -(ysp/2.+new_total_height*ispan(0,nrows-1,1))

;
; If we have figure strings, then determine white spacing around 
; the text box.
;
  if(is_figure_strings) then
    fig_index = ind(just.eq.justs)
    if(ismissing(fig_index))
      fig_index = 0
      just      = justs(fig_index)
    end if

    len_pct = 0.025           ; Percentage of width/height of plot
                              ; for white space around text box.
    if(vpw .lt. vph) then
      wsp_hpct = (len_pct * vpw) / vph
      wsp_wpct = len_pct
    else
      wsp_hpct = len_pct
      wsp_wpct = (len_pct * vph) / vpw
    end if
    para  = get_res_value(amres,"amParallelPosF",  paras(fig_index) * \
                                                   (0.5 - wsp_wpct))
    orth  = get_res_value(amres,"amOrthogonalPosF", orths(fig_index) * \
                                                    (0.5 - wsp_hpct))
  end if
;
; Variable to store rightmost location of rightmost plot, and topmost
; location of top plot.
;
  max_rgt = 0.
  max_top = 0.
;
; Variable to hold original viewport coordinates, and annotations (if
; they exist).
;
  old_vp = new((/nplots,4/),float)
  anno   = new(nplots, graphic)
;
; Loop through each row and create each plot in the new scaled-down
; size. We will draw plots later, outside the loop.
;
  num_plots_left = nplots
  nplot          = 0
  nr             = 0
  added_anno     = False             ; For figure strings
  if(isatt(res, "gsnPanelGridXF"))then
    gsnPanelGridXF = res@gsnPanelGridXF
    qsort(gsnPanelGridXF)
    print(gsnPanelGridXF)
    ngrid = dimsizes(gsnPanelGridXF)+1
    plot_lefts = new(ngrid,float)
    plot_rights = new(ngrid,float)
    plot_lefts(0) = x_lft
    plot_lefts(1:) = gsnPanelGridXF
    plot_rights(:ngrid-2) = gsnPanelGridXF
    plot_rights(ngrid-1) = x_rgt
    plot_scales = (plot_rights-plot_lefts)/total_width
    dxl = max(plot_scales) * (vpx-left)           ; Distance from plot's left
    plot_xs = plot_lefts+xwsp+dxl+xsp/2.
    print(plot_xs)
    new_plot_height = max(plot_scales)*plot_height
    new_total_height = 2.*ywsp + new_plot_height
    dyt = max(plot_scales) * (top-vpy)            ; Distance from plot's top
    ypos = y_top - ywsp - dyt -(ysp/2.+new_total_height*ispan(0,nrows-1,1))
  end if
  if(isatt(res, "gsnPanelGridYF"))then
    gsnPanelGridYF = res@gsnPanelGridYF
    qsort(gsnPanelGridYF)
    ngrid = dimsizes(gsnPanelGridYF)+1
    plot_bottoms = new(ngrid,float)
    plot_tops = new(ngrid,float)
    plot_bottoms(0) = y_bot
    plot_bottoms(1:) = gsnPanelGridYF
    plot_tops(:ngrid-2) = gsnPanelGridYF
    plot_tops(ngrid-1) = y_top
    ; plot_ys = y_top - ywsp - dyt -(ysp/2.+1-plot_tops)
    plot_scales = new(ngrid,float)
    plot_scales(0) = (y_top - dyt -plot_bottoms(ngrid-1))/total_height
    plot_scales(1) = (plot_bottoms(ngrid-1)-plot_bottoms(ngrid-2))/total_height
    ; plot_scales(2) = (plot_bottoms(ngrid-2)-plot_bottoms(ngrid-3))/total_height

    min_scale = min((/row_scale,col_scale/))
    plot_scales = where(plot_scales .ge. min_scale, min_scale, plot_scales)
    plot_ys = new(ngrid,float)
    plot_ys(0) = plot_bottoms(ngrid-1)+plot_scales(0)*total_height
    plot_ys(1) = plot_bottoms(ngrid-1)
    ; plot_ys(2) = plot_bottoms(ngrid-1)-plot_scales(1)*total_height

    ; plot_ys(2) = plot_bottoms(ngrid-2)


    ; plot_scales = (plot_ys-plot_bottoms)/total_height
    ; print(y_bot)
    ; print(plot_tops)
    ; print(plot_bottoms)
    ; print(plot_scales)
    ; print(total_height)
    ; print(plot_scales)
    ; ; print(plot_tops)
    ; ; plot_ys = plot_ys(::-1)
    ; print(plot_ys)
  end if
  do while(num_plots_left.gt.0)
    vpy_new = ypos(nr)
    new_ncols = min((/num_plots_left,row_spec(nr)/))

    if(panel_center)
      xsp = xrange - new_total_width*new_ncols  ; space before plots. 
    else
      xsp = xrange - new_total_width*ncols      ; space before plots. 
    end if
;
; Calculate new x positions.
;
  if(isatt(res, "gsnPanelGridXF"))then
    xpos = plot_xs
  else
    xpos = x_lft + xwsp + dxl +(xsp/2.+new_total_width*ispan(0,new_ncols-1,1))
  end if

  if(isatt(res, "gsnPanelGridYF"))then
    ypos = plot_ys
  end if
    do nc = 0,new_ncols-1
      vpx_new = xpos(nc)
      if(.not.ismissing(plot(nplot)))
        pplot = plot(nplot)
        getvalues pplot
          "vpXF"      : old_vp(nplot,0)
          "vpYF"      : old_vp(nplot,1)
          "vpWidthF"  : old_vp(nplot,2)
          "vpHeightF" : old_vp(nplot,3)
        end getvalues
;
; If user setting gsnPanelXF or gsnPanelYF resources, then use these instead.
; They must be set as an array of the same length as you have plots.
; If any of these are negative, then use the calculated values.
;
        vpx_new = xpos(nc)
        if(isatt(res,"gsnPanelXF").and.dimsizes(res@gsnPanelXF).eq.nplots.and.\
          res@gsnPanelXF(nplot).ge.0.and.res@gsnPanelXF(nplot).le.1) then
          vpx_new = res@gsnPanelXF(nplot)
        end if

        vpy_new = ypos(nr)
        if(isatt(res,"gsnPanelYF").and.dimsizes(res@gsnPanelYF).eq.nplots.and.\
          res@gsnPanelYF(nplot).ge.0.and.res@gsnPanelYF(nplot).le.1) then
          vpy_new = res@gsnPanelYF(nplot)
        end if

        if(isatt(res, "gsnPanelGridXF"))then
          tem_scale = plot_scales(nc)
        else
          tem_scale = scale
        end if
        if(isatt(res, "gsnPanelGridYF"))then
          tem_scale = plot_scales(nr)
        else
          tem_scale = scale
        end if
        if(isatt(res,"gsnPanelScaleF") .and.dimsizes(res@gsnPanelScaleF).eq.nplots.and.\
          res@gsnPanelScaleF(nplot).ge.0.and.res@gsnPanelScaleF(nplot).le.1) then
          tem_scale = res@gsnPanelScaleF(nplot)
          print("custom scale")
        end if
;
; Print out values used.
;
        if(panel_debug) then
          print("-------Panel viewport values for each plot-------")
          print("    plot #" + nplot)
          print("    new x,y      = " + vpx_new + "," + vpy_new)
          print("    orig wdt,hgt = " + old_vp(nplot,2) + "," + old_vp(nplot,3))
          print("    new wdt,hgt  = " + tem_scale*old_vp(nplot,2) + "," + tem_scale*old_vp(nplot,3))
        end if

        setvalues pplot
          "vpXF"      : vpx_new
          "vpYF"      : vpy_new
          "vpWidthF"  : tem_scale*old_vp(nplot,2)
          "vpHeightF" : tem_scale*old_vp(nplot,3)
        end setvalues

        if(is_figure_strings) then
          if(nplot .lt. dimsizes(panel_strings).and. \
            panel_strings(nplot).ne."")
            text = create "string" textItemClass wks
              "txString"              : panel_strings(nplot)
              "txFontHeightF"         : pfont_height
              "txPerimOn"             : perim_on
              "txBackgroundFillColor" : bkgrn
            end create
;
; Set some text resources for figure strings, if any.
;
            attsetvalues_check(text,txres)
;
; Add annotation to plot.
;
            anno(nplot) = NhlAddAnnotation(pplot,text)
            added_anno = True
            setvalues anno(nplot)
              "amZone"           : 0
              "amJust"           : just
              "amParallelPosF"   : para
              "amOrthogonalPosF" : orth
              "amResizeNotify"   : True
            end setvalues
            attsetvalues_check(anno(nplot),amres)
            delete(text)
          end if
        end if
;
; Save this plot.
;
        newplots(nplot) = pplot
;
; Info for possible labelbar or main_string
;
        if(main_string_on.or.panel_labelbar.or.draw_boxes) then
          bb  = NhlGetBB(pplot) ; Get bounding box of plot.
          top = bb(0)
          lft = bb(2)
          bot = bb(1)
          rgt = bb(3)
          max_rgt = max((/rgt,max_rgt/))
          max_top = max((/top,max_top/))

          if(draw_boxes)
            draw_bb(pplot,False)
          end if
        end if
      end if      ;   if(.not.ismissing(plot(nplot)))
;
; Retain the smallest and largest x and y positions.
;
      if(nplot.eq.0) then
        min_xpos = vpx_new
        max_xpos = vpx_new
        min_ypos = vpy_new
        max_ypos = vpy_new
      else
        min_xpos = min( (/vpx_new,min_xpos/) )
        max_xpos = max( (/vpx_new,max_xpos/) )
        min_ypos = min( (/vpy_new,min_ypos/) )
        max_ypos = max( (/vpy_new,max_ypos/) )
      end if

      nplot = nplot + 1    ; Increment plot counter
    end do  ; end of columns

    num_plots_left = nplots - nplot
    nr = nr + 1   ; increment rows
    delete(xpos)
  end do    ; end of plots

;
; Print min/max information.
;
  if(panel_debug) then
    print("-------min/max X,Y viewport positions for plots-------")
    print("min/max x viewport position = " + min_xpos + "/" + max_xpos)
    print("min/max y viewport position = " + min_ypos + "/" + max_ypos)
  end if
;
; Calculate the biggest rescaled widths and heights (technically, they
; should all be the same).  These values will be used a few times 
; throughout the rest of the code.
;
  scaled_width  = scale*max(old_vp(:,2))
  scaled_height = scale*max(old_vp(:,3))
if(panel_labelbar) then
  ;
  ; Set labelbar height, width, and font height.
  ;
    labelbar_height      = scale * labelbar_height
    labelbar_width       = scale * labelbar_width
    labelbar_font_height = font_height
    tem = lbres
      ; tem@lbLabelFontHeightF = get_res_value_keep()
    ; if(isatt(lbres,"lbLabelFontHeightF"))
    ;   tem@lbLabelFontHeightF = lbres@lbLabelFontHeightF
    ;   delete(lbres@lbLabelFontHeightF)
    ; end if
  ; draw multi labelbar
  do i = 0, dimsizes(panel_lbarid)-1
    lbres = tem
    if(panel_lbarid(i).ge.0.and.panel_lbarid(i).le.(nplots-1).and. \
       .not.ismissing(plot(panel_lbarid(i)))) then
      valid_plot_lbar = panel_lbarid(i)
    else
      valid_plot_lbar = valid_plot
    end if
    new_plot_lab = get_plot_labelbar(plot(valid_plot_lbar))
    ;---If plot type is unknown or xy, then we can't create a labelbar.
    if(panel_labelbar.and.(new_plot_lab@plot_type.eq."unknown".or.  new_plot_lab@plot_type.eq."xy")) then
      print("Warning: gsn_panel: unrecognized plot type for getting   labelbar information. Ignoring labelbar request.")
      panel_labelbar = False
    end if
  ;---Get information needed for reconstructing a labelbar from scratch.
    lbar_list = get_panel_labelbar_info(new_plot_lab)
    panel_labelbar = lbar_list[0]
    lb_label_strings := lbar_list[1]
    lb_fill_colors := lbar_list[2]
    lb_fill_patterns := lbar_list[3]
    lb_fill_scales := lbar_list[4]
    lb_mono_fill_color := lbar_list[5]
    lb_mono_fill_pattern := lbar_list[6]
    lb_mono_fill_scale := lbar_list[7]
    lb_end_style = lbar_list[8]
    lb_cap_style = lbar_list[9]
    lb_label_alignment = lbar_list[10]
    lb_subset_stuff = lbar_list[11]
  ;
  ; Check if a labelbar is to be drawn.
  ;
    lbres@lbLabelFontHeightF := labelbar_font_height
    lbres@lbLabelAlignment := lb_label_alignment
    lbres@lbMonoFillColor := lb_mono_fill_color
    lbres@vpWidthF = get_res_value_with_index(lbres,  "pmLabelBarWidthF",i,labelbar_width)
    lbres@vpHeightF = get_res_value_with_index(lbres, "pmLabelBarHeightF",i,labelbar_height)
    if(isvar("lb_cap_style"))
      lbres@lbBoxEndCapStyle := lb_cap_style
    end if

    ; set_attr(lbres,"lbMonoFillColor",lb_mono_fill_color)
    if(.not.lb_mono_fill_pattern)
      set_attr(lbres,"lbMonoFillPattern", False)
      set_attr(lbres,"lbFillPatterns", lb_fill_patterns)
    end if
    if(.not.lb_mono_fill_scale)
      set_attr(lbres,"lbMonoFillScale", False)
      set_attr(lbres,"lbFillScales", lb_fill_scales)
    end if
      lbres@EndStyle = lb_end_style
  ; Set position of labelbar depending on whether it's horizontal or
  ; vertical.
    if(lbhor)
      lbres@vpYF = max ((/ywsp+labelbar_height,bot-ywsp/))
      if(ncols.eq.1.and.lbres@vpWidthF.le.scaled_width)
        lbres@vpXF = min_xpos + (scaled_width-lbres@vpWidthF)/2.
      else
        tmp_range = x_rgt - x_lft
        lbres@vpXF = x_lft + (tmp_range - lbres@vpWidthF)/2.
      end if
      lbres@vpYF = lbres@vpYF + get_res_value_with_index(lbres, "pmLabelBarOrthogonalPosF",i,0)
      lbres@vpXF = lbres@vpXF + get_res_value_with_index(lbres, "pmLabelBarParallelPosF",i,0)
    else
      lbres@vpXF = min ((/1.-(xwsp+labelbar_width),max_rgt+xwsp/))
      if(nrows.eq.1.and.lbres@vpHeightF.le.scaled_height)
        lbres@vpYF = max_ypos-(scaled_height - lbres@vpHeightF)/2.
      else
        tmp_range = y_top - y_bot
        lbres@vpYF = y_top-(tmp_range - lbres@vpHeightF)/2.
      end if
      lbres@vpXF = lbres@vpXF + get_res_value_with_index(lbres, "pmLabelBarOrthogonalPosF",i,0.)
      lbres@vpYF = lbres@vpYF + get_res_value_with_index(lbres, "pmLabelBarParallelPosF",i,0.)
    end if

  ;   if(isvar("lb_levels"))
  ;     lb_label_strings = fix_zero_contour(lb_levels)   ; Make sure  level 0 is not something like 1e-8
  ;   end if
      lbres@SubsetStuff = lb_subset_stuff
  ;---Create the labelbar.
    copy_res_eq_with_index(tem,lbres,"lb",i)
    ; if(isatt(lbres,"lbTitleString"))
    ;   print(lbres@lbTitleString .eq. "")
    ;   lbTitleOn = False
    ; end if
    if(isatt(lbres,"lbLabelFormat"))
      lb_values := stringtofloat(lb_label_strings)
      lb_label_strings := sprintf(lbres@lbLabelFormat, lb_values)
    end if
    if(isatt(lbres,"lbLabelStrings"))
      lb_label_strings := res@lbLabelStrings
    end if
    res_to_delete = (/"pmLabelBarHeightF","pmLabelBarWidthF","pmLabelBarOrthogonalPosF","pmLabelBarParallelPosF","lbLabelFormat"/)
    delete_attrs(lbres,res_to_delete)
    newplots(nplot) = create_labelbar(wks,dimsizes(lb_fill_colors), lb_fill_colors, lb_label_strings,lbres)
    nplot = nplot + 1
  end do
end if
delete([/top,bottom,right,left/])
; lbres@lbLabelFontHeightF = tem@lbLabelFontHeightF
;
; Create the main string, if exists.
;
  if(main_string_on) then
    y_top     = min((/y_top,max_top/))
    main_ypos = get_res_value_keep(res,(/"gsnPanelMainPosYF","txPosYF"/),y_top + 0.03)
    main_xpos = get_res_value_keep(res,(/"gsnPanelMainPosXF","txPosXF"/),0.5)
    if(panel_debug) 
      print("-------Panel title values-------")
      print("    title                = " + main_string)
      print("    top of paneled plots = " + y_top)
      print("    y location of title  = " + main_ypos)
    end if

    if((main_ypos+main_font_hgt).gt.1)
       print("gsn_panel: Warning: font height (" + main_font_hgt + ") of main string is too large to fit in space provided. Either decrease font size or set gsnPanelTop.")
    end if

;
; Look for all resources that start with gsnPanelMain, and replace
; this with just "tx". This is is for backwards compatibility in
; V6.3.0 and earlier, where "gsnPanelMain" resources weren't
; recognized, but "tx" resources were.
;
    mntxres               = get_res_eq_replace(res,"gsnPanelMain","tx")
    mntxres               = True
    mntxres@gsnDraw       = False
    mntxres@gsnFrame      = False
    mntxres@txFontHeightF = main_font_hgt
    newplots(nplot) = gsn_create_text_ndc(wks, main_string, main_xpos, \
                      main_ypos, mntxres)
    mntxres = get_res_eq(res,"tx")   ; This is a kludge to remove any tx*** resources from "res"
  end if
;
; If some of the paneled plots are missing, we need to take these into
; account so that the maximization will still work properly.  For
; example, if we ask for a 2 x 2 configuration, but plots 1 and 3 (the
; rightmost plots) are missing, then we need to set a new resource
; called gsnPanelInvsblRight to whatever approximate X value it 
; would have been if those plots weren't missing.  Setting just gsnPanelRight
; won't work in this case, because that resource is only used to control
; where the plots are drawn in a 0 to 1 square, and *not* to indicate the
; rightmost location of the rightmost graphic (which could be a vertical 
; labelbar).
;
; Not dealing with the case of gsnPanelRowSpec = True yet.
;  
  if(.not.is_row_spec) then
    newbb  = new((/dimsizes(newplots),4/),float)
;
; Have to deal with special case of only having one plot.
;
    if(dimsizes(newplots).eq.1)
      newbb(0,:)  = NhlGetBB(newplots)  ; Get bounding boxes of plots, plus
                                        ; labelbar and text string if they
                                        ; exist.  
    else
      newbb  = NhlGetBB(newplots)       ; Get bounding boxes of plots, plus
                                        ; labelbar and text string if they
                                        ; exist.  
    end if
    getvalues newplots(valid_plot)
      "vpXF"      : vpx
      "vpYF"      : vpy
      "vpWidthF"  : vpw
      "vpHeightF" : vph
    end getvalues
    dxl = vpx-newbb(valid_plot,2)
    dxr = newbb(valid_plot,3)-(vpx+vpw)
    dyt = (newbb(valid_plot,0)-vpy)
    dyb = (vpy-vph)-newbb(valid_plot,1)
;
; Get largest bounding box that encompasses all non-missing graphical
; objects.
;
    newtop = max(newbb(:,0))
    newbot = min(newbb(:,1))
    newlft = min(newbb(:,2))
    newrgt = max(newbb(:,3))
    delete(newbb)

;
; This section checks to see if all plots along one side are 
; missing, because if they are, we have to pretend like they
; are just invisible (i.e. do the maximization as if the invisible
; plots were really there).  This section needs to take
; place even if no plots are missing, because it's possible the
; user specified fewer plots than panels.
;
    xlft = min_xpos - dxl
    xrgt = max_xpos + vpw + dxr
    xtop = max_ypos + dyt
    xbot = min_ypos - vph - dyb
    if(.not.rgt_pnl.and.xrgt.gt.newrgt) then
      maxbb@gsnPanelInvsblRight = xrgt
      if(panel_debug)
        print("gsnPanelInvsblRight = " + maxbb@gsnPanelInvsblRight)
      end if
    end if

    if(.not.lft_pnl.and.xlft.lt.newlft) then
      maxbb@gsnPanelInvsblLeft = xlft
      if(panel_debug)
        print("gsnPanelInvsblLeft = " + maxbb@gsnPanelInvsblLeft)
      end if
    end if

    if(.not.top_pnl.and.xtop.gt.newtop) then
      maxbb@gsnPanelInvsblTop = xtop
      if(panel_debug)
        print("gsnPanelInvsblTop = " + maxbb@gsnPanelInvsblTop)
      end if
    end if

    if(.not.bot_pnl.and.xbot.lt.newbot) then
      maxbb@gsnPanelInvsblBottom = xbot
      if(panel_debug)
        print("gsnPanelInvsblBottom = " + maxbb@gsnPanelInvsblBottom)
      end if
    end if
  end if
; 
; Draw plots plus labelbar and main title (if they exists). This is
; also where the plots will be maximized for PostScript output,
; if so indicated.
;
  if(draw_boxes)
    draw_and_frame(wks,newplots,calldraw,False,1,maxbb)
  else
    draw_and_frame(wks,newplots,calldraw,callframe,1,maxbb)
  end if  
;
; Draw bounding boxes around each plot object for debugging purposes.
;
  if(draw_boxes)
    do i=0,dimsizes(newplots)-1
      if(.not.ismissing(newplots(i)))
        draw_bb(newplots(i),False)
      end if
    end do
    if(callframe) then
      frame(wks)
    end if
  end if
;
; Debug information
;
  if(panel_debug) then
    bb_dbg = NhlGetBB(newplots)
    if(dimsizes(newplots).gt.1) then
      print("-------min/max NDC values for all objects in panel-------")
      print("min/max x position = " + min(bb_dbg(:,2)) + "/" + max(bb_dbg(:,3)))
      print("min/max y position = " + min(bb_dbg(:,1)) + "/" + max(bb_dbg(:,0)))
    else
      print("-------min/max NDC values for the object in panel-------")
      print("min/max x position = " + min(bb_dbg(2)) + "/" + max(bb_dbg(3)))
      print("min/max y position = " + min(bb_dbg(1)) + "/" + max(bb_dbg(0)))
    end if
    delete(bb_dbg)
  end if
    
;
; Restore plots to original size.
;
  if(.not.panel_save) then
    do i=0,nplots-1
      if(.not.ismissing(plot(i)))
        if(added_anno.and..not.ismissing(anno(i)))
          NhlRemoveAnnotation(plot(i),anno(i))
        end if
        setvalues plot(i)
          "vpXF"      : old_vp(i,0)
          "vpYF"      : old_vp(i,1)
          "vpWidthF"  : old_vp(i,2)
          "vpHeightF" : old_vp(i,3)
        end setvalues
      end if
    end do
  end if

  return(newplots)
end

; undef("gsn_panel")
; procedure gsn_panel(wks:graphic,plot[*],dims[*]:integer,\
;                     resources:logical)
; local res2
; begin
;   res2 = get_resources(resources)
;   set_attr(res2,"gsnPanelSave",False )
;   if(typeof(plot) .eq. "list")
;     dim = ListCount(plot)
;     newPlot = new(dim,graphic)
;     do i = 0, dim-1
;       newPlot(i) = plot[i]
;     end do
;     plots = gsn_panel_return(wks,newPlot,dims,res2)
;   else
;     plots = gsn_panel_return(wks,plot,dims,res2)
;   end if
; end

undef("add_filled_boxes")
procedure add_filled_boxes(wks,plot,data,levels,colors,opt)
local dims,gnid, gnres, ii, jj, nrows, ncols, boxx, boxy, index, tem,gnidString
begin
  dims = dimsizes(data)
  nrows = dims(0)
  ncols = dims(1)
  tem = ispan(0, dimsizes(colors)-1, 1)
	gnid = new((/nrows,ncols/),"graphic")
        gnres = True     ; resource list for filled polygons
        do jj = 0,nrows-1
          do ii = 0,ncols-1
                boxx = (/ii,ii,ii+1,ii+1,ii/)+opt@trXMinF
                boxy = (/jj,jj+1,jj+1,jj,jj/)+opt@trYMinF
    index = GetFillColorIndex(levels, tem, data(jj,ii))
		; index = closest_val(data(jj,ii),levels)
                gnres@gsFillColor = colors(index)
                gnid(jj,ii) = gsn_add_polygon(wks,plot,boxx,boxy,gnres)
        end do
      end do
  gnidString = unique_string("gnid")
      plot@$gnidString$ = gnid
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Add text strings to every filled box showing the data value.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
undef("add_text_strings")
procedure add_text_strings(wks,plot,data,opt)
local txres, xpos, ypos, dims, nrows, cols, format
begin
      dims = dimsizes(data)
      nrows = dims(0)
      ncols = dims(1)
      txres               = True
      txres@txFontHeightF = 0.01
      txres@txJust        = "CenterCenter"
      copy_VarAtts_match(opt,txres,"tx","")
      format = get_res_value_keep(opt, "hmLabelFormat","%0.1f")
      xpos = conform_dims((/nrows,ncols/),ispan(0,nrows-1,1),0) + 0.5
      ypos = conform_dims((/nrows,ncols/),ispan(0,ncols-1,1),1) + 0.5
      plot@txid = gsn_add_text(wks,plot,sprintf(format,data),ypos,xpos,txres)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Attach a horizontal labelbar to the bottom of a plot.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
undef("add_heatMapLabelbar")
procedure add_heatMapLabelbar(wks,plot,colors,labels,opt)
local nboxes, vph, vpw, nboxes, lbres, lbid, amres, annoid
begin
  nboxes = dimsizes(colors)

  getvalues plot                      ; Get plot size for use in
    "vpHeightF" : vph                 ; creating labelbar.
    "vpWidthF"  : vpw
  end getvalues

  lbres                    = True          ; labelbar only resources
  lbres@lbAutoManage       = False         ; Necessary to control sizes
  lbres@lbFillColors       = colors        ; labelbar colors
  lbres@lbMonoFillPattern  = True          ; Solid fill pattern
  lbres@lbLabelFontHeightF = 0.02          ; font height. Default is small
  lbres@lbLabelAlignment   = "InteriorEdges"
  lbres@lbOrientation      = "horizontal"
  lbres@lbPerimOn          = False

  lbres@vpWidthF           = vpw * 0.95   ; Make labelbar slightly shorter than width of plot
  lbres@vpHeightF          = vph * 0.25
  if(isatt(opt, "pmLabelBarWidthF"))then
    lbres@vpWidthF = opt@pmLabelBarWidthF
  end if
  if(isatt(opt, "pmLabelBarHeightF"))then
    lbres@vpHeightF = opt@pmLabelBarHeightF
  end if
  ; if(isatt(lbres,"lbLabelFormat"))
  ;   ; lb_values := stringtofloat(lb_label_strings)
  ;   labels := sprintf(lbres@lbLabelFormat, lb_values)
  ; end if
  copy_VarAtts_match(opt,lbres,"lb","")

  lbid = gsn_create_labelbar(wks,nboxes,labels,lbres)
  ; add_YRAxisString(lbid,"test",True)
; Set some annotation resources indicating how we want to attach
; the labelbar to the plot. Here, we are using the top right
; corner of the labelbar as the point which we are going to position
; it, and then we use amParallelPosF and amOrthogonalPosF to
; indicate where we want to place it.
;
; amParallelPosF/amOrthogonalPosF                                       ;
;    0.0/ 0.0  -  annotation in dead center of plot
;    0.5/ 0.5  -  annotation at bottom right of plot
;    0.5/-0.5  -  annotation at top right of plot
;   -0.5/-0.5  -  annotation at top left of plot
;   -0.5/ 0.5  -  annotation at bottom left of plot
;                                                                 
  amres                  = True
  amres@amJust           = "BottomCenter"
  amres@amParallelPosF   = 0.0     ; Centered about X axis
  amres@amOrthogonalPosF = 0.9     ; Move labelbar down
  if(isatt(opt, "pmLabelBarOrthogonalPosF"))then
    amres@amOrthogonalPosF = opt@pmLabelBarOrthogonalPosF
  end if
  if(isatt(opt, "pmLabelBarParallelPosF"))then
    amres@amParallelPosF = opt@pmLabelBarParallelPosF
  end if
  plot@annoid = gsn_add_annotation(plot,lbid,amres)
  ; text := "test"
  ;   text@txJust = "CenterLeft"
  ; add_string(plot,text,amres@amParallelPosF+lbres@vpWidthF,1-amres@amOrthogonalPosF)
end

undef("heatmap")
function heatmap(wks,data,levels,colors,opt)
local res,plot,dim
begin
dim = dimsizes(data)
res = True
	res@gsnDraw     = False
	res@gsnFrame    = False
  ; res@gsnScale    = True
  res@gsnMaximize = True

  res@vpWidthF    = 0.8     ; Change aspect ratio such that
  res@vpHeightF   = 0.4     ; boxes are square

;---Set the min/max for X axis

	res@trXMinF                 = 0 
	res@trXMaxF                 = dim(1)
	res@trYMinF                 = 0
	res@trYMaxF                 = dim(0)
;---Turn on X and Y grid lines
  res@tmXMajorGrid            = False
  res@tmYMajorGrid            = False
  res@tmYMinorGrid = True
  res@tmXMinorGrid = True

;---Turn off top and right tickmarks and labels
	res@tmXTOn                  = False
	res@tmYROn                  = False
if(isdimnamed(data, 1))then
  dimNames = getvardimnames(data)
  if(iscoord(data, dimNames(1)))then
    coord = data&$dimNames(1)$
    res@trXMinF                 = coord(0)
	  res@trXMaxF                 = coord(dimsizes(coord)-1)+1
  end if
end if
;---Customize X and Y axis tickmark labels
	res@tmXBMode                = "Explicit"
	res@tmXBValues              = ispan(res@trXMinF,res@trXMaxF-1,1)+0.5
  ; print(res@tmXBValues)
  res@tmXBMinorValues = ispan(res@trXMinF+1,res@trXMaxF-1,1)
  res@tmXBMinorOutwardLengthF = 0
  res@tmXBMinorLengthF = 0
	res@tmXBLabels              = ispan(res@trXMinF,res@trXMaxF-1,1)
	res@tmYLMode               = "Explicit"
	res@tmYLValues             = ispan(res@trYMinF,res@trYMaxF-1,1)+0.5
	res@tmYLLabels             = ispan(1,dim(0),1)
  res@tmYLMinorValues = ispan(res@trYMinF+1,res@trYMaxF-1,1)
  res@tmYLMinorOutwardLengthF = 0
  res@tmYLMinorLengthF = 0

	res@tmXBLabelFontHeightF   = 0.015
	res@tmYLLabelFontHeightF   = 0.015
  res@tmXBMajorLengthF = 0.005
  res@tmXBMajorOutwardLengthF = 0.005
  res@tmYLMajorLengthF = 0.005
  res@tmYLMajorOutwardLengthF = 0.005
  copy_VarAtts_match(opt,res,res_plot,"")
  ; print(opt@tmXBLabels)
  if(isatt(opt, "tmXBTickSpacingF"))then
	  res@tmXBValues := res@tmXBValues(::opt@tmXBTickSpacingF)
    print(res@tmXBValues)
    if( .not. isatt(opt, "tmXBLabels"))then
      res@tmXBLabels := res@tmXBLabels(::opt@tmXBTickSpacingF)
    end if
  end if
;---Create a blank plot so gsn_add_polygon function can be used
	plot = gsn_csm_blank_plot(wks,res)

;---Fill each grid box according to which level value it is closest to.
  add_filled_boxes(wks,plot,data,levels,colors,res)

  if(isatt(opt,"gsnCornerString"))
    print("add corner")
    corner = opt@gsnCornerString
    if(.not. isatt(opt,"gsnCornerStringFontHeightF") .and. isatt(opt,"gsnLeftStringFontHeightF"))
      opt@gsnCornerStringFontHeight = res@gsnLeftStringFontHeightF
    end if
    copy_VarAtts_eq(opt,corner,"gsnCorner")
    ; res_text = get_res_eq(opt,"gsnCorner")
    add_CornerString(plot,corner)
  end if
;---Add text strings and labelbar and draw plot again
  if(get_res_value_keep(opt, "hmTxOn", True))then
    add_text_strings(wks,plot,data,opt)
  end if
  if(get_res_value_keep(opt, "lbLabelBarOn",True))
    add_heatMapLabelbar(wks,plot,colors,""+levels,opt)
  end if
  if(get_res_value_keep(opt, "gsnDraw", True))then
    draw(plot)
  end if
  if(get_res_value_keep(opt, "gsnFrame", True))then
    frame(wks)
  end if
        ; draw(plot)
        ; frame(wks)
  return plot
end

undef("gsn_table")
function gsn_table(wks:graphic,ncr[2]:integer,text:string,res:logical)
local plot,nrows, ncols, x,y,xPoss,i, ii, txres, txres2, lnres, attnames, natts, text2d,xpos,ypos
begin
  nrows = ncr(0)
  ncols = ncr(1)
  ;
  ; Get ready to draw table.
  ;
    xsize = 1./ncols         ; width of grid cell
    ysize = 1./nrows         ; height of grid cell

  ;
  xPoss = new(ncols+1, float)
  xPoss(0) = 0
  xPoss(ncols) = 1
  do nc = 1,ncols-1
    xPoss(nc) = xPoss(0)+(nc * xsize)
    ; xpos = x(0) + (nc * xsize);控制竖线的位置
    if(isatt(res, "tbLinePosXF"))
      xPoss(nc+1) = res@tbLinePosXF(nc)
    end if
  end do
  x = (/0,1./)
  y = (/0,1./)
  res@tmXBOn = False
  res@tmYLOn = False
  res@tmYROn = False
  res@tmXTOn = False
  ; res@gsnLeftStringOrthogonalPosF = 0.05
  plot = gsn_csm_blank_plot(wks, res)
  debug = get_res_value(res,"gsnDebug",False)

;
; Error checking.
;
  if(nrows.lt.1.or.ncols.lt.1) then
     print("gsn_table: nrows and ncols must be >= 1.")
     exit
  end if
  if(any(x.lt.0.or.x.gt.1.or.y.lt.0.or.y.gt.1)) then
     print("gsn_table: the begin and end x and y values must")
     print("           be in the range [0,1].")
     exit
  end if

  if(x(1).le.x(0).or.y(1).le.y(0)) then
    print("gsn_table: the begin x,y points must be less")
    print("           than the end x,y points.")
    exit
  end if

;
; Check if text desired.
;
  if(.not.all(ismissing(text))) then
    text_avail = True
  else
    text_avail = False
  end if

  if(text_avail) then
; 
; Check that the text dimens are correct.  If you have nrows x ncols,
; then the text can either be (nrows x ncols) strings, a scalar string,
; or (ncols) if nrows=1, or (nrows) if ncols=1.
;
    dsizes_text = dimsizes(text)
    rank_text   = dimsizes(dsizes_text)
    if( (rank_text.ne.2.and.rank_text.ne.1).or.\
        (rank_text.eq.1.and.(nrows.ne.1.and.ncols.ne.1)).or.\
        (rank_text.eq.1.and.(nrows.eq.1.and.ncols.ne.dsizes_text)).or.\
        (rank_text.eq.1.and.(ncols.eq.1.and.nrows.ne.dsizes_text)).or.\
        (rank_text.ne.2.and.(nrows.gt.1.and.ncols.gt.1)) ) then
      print("gsn_table: the dimensionality of the text must be ")
      print("           " + nrows + " row(s) x " + ncols + " column(s).")
      exit
    end if
  end if

;
; Check all resource values. They must either be scalars, or
; arrays of same size as nrows x ncols.
;
  res2     = False
  attnames = getvaratts(res)
  table_fill_res(res,res2,ncr,attnames)
  delete(attnames)                    ; We're going to use this later.


; Check for a box fill color.
;
  fill_on = False
  if(isatt(res2,"gsFillColor").or.isatt(res2,"gsFillIndex")) then
    fill_on = True
  end if
  gsres_tmp = get_res_eq(res,"gs")           ; Get resource list for lines. Remove gsFill
  lnres     = get_res_ne(gsres_tmp,"gsFill")  ; resources so they don't get passed to gsn_polyline.
  delete(gsres_tmp)
;
; Check for desired filling of each grid cell. Do this before drawing
; grid lines, because we want lines drawn on top of filled boxes.
;
  if(fill_on) then
    gonres = get_res_eq(res2,"gsFill")     ; Get fill resources.
    gonres2 = True
    attnames = getvaratts(gonres)
    natts    = dimsizes(attnames)
    if(isatt(res, "tbSpecFillColor"))then
      FillParas = str_split(res@tbSpecFillColor, ",")
      specX = stringtoint(FillParas(0))-1
      specY = stringtoint(FillParas(1))-1
      specColor = FillParas(2)
    end if
    do nr = 0,nrows-1
      ypos = y(1) - ((nr+1) * ysize)
      do nc = 0,ncols-1
        ii = nr*ncols+nc
;
; Copy all resources over to temporary array.
;
        do i=0,natts-1
          gonres2@$attnames(i)$ = gonres@$attnames(i)$(ii)
        end do
        if(isvar("FillParas"))then
          gonres2@gsFillColor = specColor
        else
          delete(gonres2@gsFillColor)
        end if
        ; xpos = x(0) + (nc * xsize)
        uni = unique_string("line")
        plot@$uni$ = gsn_add_polygon(wks,plot,(/xPoss(nc),xPoss(nc+1),xPoss(nc+1),xPoss(nc),xPoss(nc)/), \
                            (/ypos,ypos,ypos+ysize,ypos+ysize,ypos/),gonres2)
      end do
    end do
    delete(attnames)                    ; We're going to use this later.
  end if

; Draw horizontal lines, top to bottom.

  do nr = 0,nrows
    ypos = y(1) - (nr * ysize)
    ii = nr*ncols
    uni = unique_string("line")
    plot@$uni$ = gsn_add_polyline(wks,plot,(/x(0),x(1)/),(/ypos,ypos/),lnres)
    if(debug) then
      print("Horizontal line from (" + x(0) + "," + ypos + ") to (" + \
                                      x(1) + "," + ypos + ")")
    end if
  end do

; Draw vertical lines, left to right.
  do nc = 0,ncols-2
    uni = unique_string("line")
    plot@$uni$ = gsn_add_polyline(wks,plot,(/xPoss(nc+1),xPoss(nc+1)/),(/y(0),y(1)/),lnres)
    if(debug) then
      print("Vertical line from (" + xpos + "," + y(0) + ") to (" + \
                                     xpos + "," + y(1) + ")")
    end if
  end do

;
; Draw text, if any.  The text will be drawn left to right,
; top to bottom.
;
  if(text_avail) then
    txres = get_res_eq(res2,"tx")     ; Get text resources.
;
; Conform text to nrows x ncols if it is 1D.
;
    if(rank_text.eq.1) then
      text2d = new((/nrows,ncols/),string)
      if(nrows.eq.1) then
        text2d(0,:) = text
      else
        text2d(:,0) = text
      end if
    else
      text2d = text       ; Already 2D.
    end if

    xsize2 = xsize/2.     ; Half width of box.
    ysize2 = ysize/2.     ; Half height of box.

;
; All text resources should be nrows x ncols at this point. Now,
; for each individual text string, we need to grab the appropriate
; resource value, and attach it to a new resource list.
;
    txres2 = True    ; True no matter what, because we have to at least set
                     ; txJust.
;
; If txJust is not being set, use "CenterCenter" for each one.
; Note that if txres is set to False and it is setting txJust,
; it will be ignored. that's because setting txres=False means
; ignore all attributes set to this logical variable.
;
    if(.not.txres.or.(txres.and..not.isatt(txres,"txJust"))) then
      txres = True
      txres@txJust    = new(nrows*ncols,string)
      txres@txJust(:) = "CenterCenter"
    end if      

    attnames = getvaratts(txres)
    natts    = dimsizes(attnames)
    if(isatt(res, "tbSpecFontColor"))then
      FontParas = str_split(res@tbSpecFontColor, ",")
      specX = stringtoint(FontParas(0))-1
      specY = stringtoint(FontParas(1))-1
      specColor = FontParas(2)
    end if
    do nr = 0,nrows-1
      do nc = 0,ncols-1
        
        if(.not.ismissing(text2d(nr,nc))) then
          ii = nr*ncols+nc
;
; Copy all resources over to temporary array.
;
          do i=0,natts-1
            txres2@$attnames(i)$ = txres@$attnames(i)$(ii)
          end do
          if(isvar("FontParas") .and. nc .eq. specX .and. nr .eq. specY)
            txres2@txFontColor = specColor
          else
            delete(txres2@txFontColor)
          end if
; 
; Check the text justification.
;
          txjust = txres2@txJust

          if(any(str_lower(txjust).eq. \
                 (/"bottomleft","bottomcenter","bottomright"/))) then
            ypos = y(1) - ((nr+1) * ysize)
          end if
          if(any(str_lower(txjust).eq. \
                 (/"centerleft","centercenter","centerright"/))) then
            ypos = (y(1) - ((nr+1) * ysize)) + ysize2
          end if
          if(any(str_lower(txjust).eq. \
                 (/"topleft","topcenter","topright"/))) then
            ypos = y(1) - (nr * ysize)
          end if
          if(any(str_lower(txjust).eq. \
                 (/"bottomleft","centerleft","topleft"/))) then
            xpos = x(0) + (nc * xsize)
          end if
          if(any(str_lower(txjust).eq. \
                 (/"bottomcenter","centercenter","topcenter"/))) then
            if(isatt(res, "tbTextPosXF"))
              xpos = res@tbTextPosXF(nc) + xsize2
            else
              xpos = (xPoss(nc)+xPoss(nc+1))*0.5
              ; xpos = (x(0) + (nc * xsize)) + xsize2
            end if
          end if
          if(any(str_lower(txjust).eq. \
                 (/"bottomright","centerright","topright"/))) then
            xpos = x(0) + ((nc+1) * xsize)
          end if
; Draw text.
          uni = unique_string("line")
          plot@$uni$ = gsn_add_text(wks,plot,text2d(nr,nc),xpos,ypos,txres2)
        end if
      end do
    end do
  end if
  if(.not. isatt(res, "gsnDraw") .or. res@gsnDraw)then
    draw(plot)
  end if
  if( .not. isatt(res, "gsnFrame") .or. res@gsnFrame)then
    frame(wks)
  end if
  return plot
end