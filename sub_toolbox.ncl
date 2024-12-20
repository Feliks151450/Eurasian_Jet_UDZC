undef("setDim")
procedure setDim (var,dimInd,dimName,coord)
begin
  var!dimInd = dimName
  if(iscoord(var, dimName))
    delete(var&$dimName$)
  end if
  var&$dimName$ = coord
end

undef("strIncludes")
function strIncludes(str,substr)
begin
  return isStrSubset(str, substr)
end

undef("strReplace")
function strReplace(str,oldStr,newStr)
begin
  return str_sub_str(str, oldStr, newStr)
end

undef("strIndexOf")
function strIndexOf(str,substr)
begin
  return str_index_of_substr(str, substr, 1)
end

undef("strLastIndexOf")
function strLastIndexOf()
begin
  return str_index_of_substr(str, substr, -1)
end

undef("strSlice")
function strSlice(str,startIndex,endIndex)
begin
  return str_get_cols([str], startIndex, endIndex)
end

undef("subStr")
function subStr(str,startIndex,length)
begin
  return str_get_cols([str], startIndex, startIndex+length-1)
end

undef("strStartsWith")
function strStartsWith(str,testStr)
local tem
begin
  tem = strSlice(str,0,strlen(testStr)-1)
  print(tem)
  return tem .eq. testStr
end

undef("strEndsWith")
function strEndsWith(str,testStr)
local tem
begin
  tem = strSlice(str,strlen(str)-strlen(testStr),strlen(str))
  print(tem)
  return tem .eq. testStr
end
undef("strTrim")
function strTrim(str)
begin
  return str_strip(str)
end
undef("strRepeat")
function strRepeat(str,repeat)
local tem
begin
  tem = ""
  do i = 0, repeat -1
    tem = tem+str
  end do
  return tem
end
undef("bold")
function bold(str)
begin
  return "~F22~"+str+"~F21~"
end

undef("genItem")
function genItem(item,type)
local type_upper
begin
  type_upper = str_upper(type)
  if(type_upper .eq. "NATURE")then
    return "~F22~"+str_lower(item)+"~F21~"
  end if
  if(type_upper .eq. "SCIBULL")then
    return "~F22~("+str_lower(item)+")~F21~"
  end if
  if(type_upper .eq. "SCIENCE")then
    return "~F22~"+str_upper(item)+"~F21~"
  end if
  if(type_upper .eq. "NSR")then
    return "~F22~"+str_lower(item)+"~F21~"
  end if
  return item
end

undef("checkAtt")
function checkAtt(res,att)
begin
  if(.not. isatt(res, att))then
    return False
  end if

  if(ismissing(res@$att$))then
    return False
  end if
  
  return True
end
undef("printx")
procedure printx(str)
  begin
  print("----------------------------------------------------")
  print(""+str)
  print("----------------------------------------------------")
end

undef("trim")
procedure trim(fileName[1])
local type
begin
  if(typeof(fileName) .eq. "string")then
    system("convert "+fileName+".png -trim +repage -bordercolor white -border 1%x1%x1%x1% "+fileName+".png")
  elseif(NhlIsWorkstation(fileName))then
    if(isatt(fileName, "path"))
      system("convert "+fileName@path+".png -trim +repage -bordercolor white -border 1%x1%x1%x1% "+fileName@path+".png")
    end if
  end if
end

undef("cond")
function cond(con,true,false)
begin
  if(con)then
    return true
  else
    return false
  end if
end
undef("arange")
function arange(args)
local type,dim,tem
begin
  type = typeof(args)
  if(type .eq. "integer")then
    if(isArray(args))then
      dim = dimsizes(args)
      if(dim .eq. 2)then
        return ispan(args(0), args(1), 1)
      elseif(dim .eq. 3)then
        return ispan(args(0), args(1), args(2))
      end if
    else
      return ispan(0, args, 1)
    end if
  elseif(type .eq. "float")
    if(isArray(args))then
      dim = dimsizes(args)
      if(dim .eq. 2)then
        dim = tointeger((args(1)-args(0)))
        return args(0)+ispan(0, dim, 1)
      elseif(dim .eq. 3)then
        dim = tointeger((args(1)-args(0))/args(2))
        return args(0)+ispan(0, dim, 1)*args(2)
      end if
    else
      tem := tointeger(args)
      tem := ispan(0, tem, 1)
      return tofloat(tem)
    end if
  end if
  return 0
end

undef("pdf2png")
procedure pdf2png(fileName)
begin
  system("convert -density 300 "+fileName+".pdf -quality 100 "+fileName+".png")
end

undef("print_error")
procedure print_error(str[1])
  begin
  pre = "echo "+str_get_dq()+"\033[91m"
  pos = "\033[0m"+str_get_dq()
  tem = pre+"---------------------------------------------------"
  tem = tem+str_get_nl()+"error: "+str
  tem = tem+str_get_nl()+"---------------------------------------------------"
  output = tem+pos
  system(output)
  exit
end

undef("echo")
procedure echo(str)
begin
  system("echo -e '"+str+"'")
end

undef("printc")
procedure printc (str:string,color)
local dashLineOn,colors,colors_code,pos,pre,lenMax,tem_str,dashLine,output,i,str,tem
begin
dashLineOn = get_res_value_keep(color,"dashLineOn",True)
colors = (/"red", "green", "yellow","blue","purple"/)
if(ismissing(get_script_name()))
  colors_code = str_get_nl()+(/"","","","",""/)
  pos = str_get_dq()
else
  colors_code = str_get_nl()+"\e["+(/"91m","92m","93m","94m","95m"/)
  pos = "\e[0m"+str_get_dq()
end if
; color = get_res_value_keep(opt,"color","purple")
pre = "echo -e "+str_get_dq()
color_code = colors_code(ind(colors .eq. color))
if(dashLineOn)
  lenMax = max(strlen(str))
  tem_str = new(lenMax+2,string)
  tem_str = "-"
end if
dashLine = where(dashLineOn,color_code+str_concat(tem_str),"")
output = pre+dashLine

do i = 0, dimsizes(str)-1
  ; pad = new(lenMax-strlen(str)+1,string)
  ; pad = " "
  ; pad_str = str_concat(pad)
  if(dimsizes(color) .eq. 1)
    tem = colors_code(ind(colors .eq. color))+" "+str(i)
  else
    tem = colors_code(ind(colors .eq. color(i)))+" "+str(i)
  end if
  output = output+tem
end do
output = output+dashLine+pos
system(output)
end

undef("repeat")
function repeat(str,n)
local tem_str
begin
  if(n .le. 0)then
    return ""
  end if
  tem_str = new(n, string)
  tem_str = str
  return str_concat(tem_str)
end

undef("progress")
procedure progress(p[1]:integer)
local clrs,clrs_code,pre,post,dif
begin
  clrs =      (/"none","red"    , "green",  "yellow", "blue"  ,"purple"/)
  clrs_code = (/""    ,"\e[91m" ,"\e[92m",  "\e[93m", "\e[94m","\e[95m"/)
  post = "\e[0m"
  if(isatt(p, "total"))then
    dif = p@total-p
    if(dif .le. 0)then
      post = "]["+p+"/"+p@total+"]"+"\n\n\e[K"+post
    else
      post = repeat(" ",dif)+"]["+p+"/"+p@total+"]"+post
    end if
  end if
  ; print(get_res_value_keep(p, "color", "none"))
  pre = clrs_code(ind(clrs .eq. get_res_value_keep(p, "color", "none")))
  if(p .eq. 0)then
    echo(str_get_nl()+"\e[1A"+pre+"[>"+post)
  else
    echo(str_get_nl()+"\e[1A\e[2K"+pre+"["+repeat("=",p)+">"+post)
  end if
end

undef("remove")
procedure remove (f[1]:string)
begin
  system("rm -rf "+f)
end

undef("minus")
function minus (a,b)
begin
  c = a-b
  copy_VarCoords(a,c)
  return(c)
end

undef("superScript")
function superScript (text[1]:string)
begin
  return ("~S~"+text+"~N~")
end

undef("newPlots")
function newPlots (size[1])
local plot
begin
  plot = new(size,graphic)
  plot!0 = "plot"
  plot&plot = ispan(0, size-1, 1)
  isShaded = new(size,logical)
  isShaded = False
  plot@isShaded = isShaded
  return(plot)
end

undef("newColors")
function newColors (size[1],color)
begin
  colors = new(size,string)
  colors = "steelblue"
  return(colors)
end

undef("createList")
function createList (size,type)
begin
  ls = NewList("fifo")
  tem = 0
  do i = 0, size -1
    str = unique_string("list")
    tem@$str$ = new(1,"graphic")
    ListAppend(ls, tem@$str$)
    ls[i]@fromList = True
  end do
  return(ls)
end

undef("ind_dev2")
function ind_dev2(X[*],X0[*],Y[*],Y0[*])
local dim,tem,i
begin
  dim = dimsizes(X)
  tem = new(dim,logical)
  do i = 0, dim-1
    tem(i) = any(X0 .eq. X(i)) .and. any(Y0 .eq. Y(i))
  end do
  return(ind(tem))
end

undef("ind_dev")
function ind_dev (X[*],Y[*])
local dim,tem,i
begin
  dim = dimsizes(X)
  tem = new(dim,logical)
  do i = 0, dim-1
    tem(i) = any(Y .eq. X(i))
  end do
  return(ind(tem))
end

undef("pop")
function pop(var,element_to_pop)
local dim,tem,i
begin
  dim = dimsizes(var)
  tem = new(dim,logical)
  do i = 0, dim-1
    tem(i) = all(element_to_pop .ne. var(i))
  end do 
  return(var(ind(tem)))
end

undef("popYear")
function popYear(var,element_to_pop)
local dim,year,tem,i
begin
  dim = dimsizes(var)
  year = var&year
  tem = new(dim,logical)
  do i = 0, dim-1
    tem(i) = all(element_to_pop .ne. year(i))
  end do 
  return(var(ind(tem)))
end

undef("quicklook")
procedure quicklook(fileName,fig)
begin
  if(fig .eq. "pdf")
    system("sips -s format png "+fileName+".pdf"+" -o "+fileName+".png")
  end if
  system("sips --cropToHeightWidth 2850 2850 "+fileName+".png")
  system("open -a /System/Applications/Preview.app "+fileName+".png")
  system("open -a /Applications/Visual\ Studio\ Code.app")
end

undef("show")
procedure show(fileName[1])
local type,tem
begin
  if(typeof(fileName) .eq. "string")then
    if(strEndsWith(fileName,"png"))then
      print("showImage: "+fileName)
    else
      print("showImage: "+fileName+".png")
    end if
  elseif(NhlIsWorkstation(fileName))then
    if(isatt(fileName, "path"))
      print("showImage: "+fileName@path)
    end if
  end if
end

undef("notDrawAndFrame")
procedure notDrawAndFrame(res)
begin
  res@gsnDraw = False
  res@gsnFrame = False
  return
end

undef("t_value")
function t_value(df)
local t
begin
  t = True
  t@t80 = cdft_t(0.9,df)
  t@r85  = t@t80/sqrt(df+t@t80^2)
  t@t85 = cdft_t(0.925,df)
  t@r85  = t@t85/sqrt(df+t@t85^2)
  t@t90  = cdft_t(0.95,df)
  t@r90  = t@t90/sqrt(df+t@t90^2)
  t@t95  = cdft_t(0.975,df)
  t@r95  = t@t95/sqrt(df+t@t95^2)
  t@t99  = cdft_t(0.995,df)
  t@r99  = t@t99/sqrt(df+t@t99^2)
  t@t999 = cdft_t(0.9995,df)
  t@r999 = t@t999/sqrt(df+t@t999^2)
return(t)
end

undef("R2t")
function R2t(R,df)
begin
  return sqrt(df)*abs(R)/sqrt(1-R^2)
end

undef("R2p")
function R2p(R,df)
local t,p
begin
  t  = sqrt(df)*abs(R)/sqrt(1-R^2)
  p = cdft_p(t, df)
  return (1-p)*2
end

undef("_designal") ; FX| designal
function _designal(X,ts)
local rec,dim_rec,Xd,dimX,rec_con,ts_con,type
begin
  rec = regCoef_n(ts,X,0,0)
  dim_rec = dimsizes(rec)
  if(dimsizes(dim_rec) .eq. 1 .and. dim_rec .eq. 1)
    Xd = X - rec*ts
    copy_VarCoords(ts, Xd)
  else
    dimX = dimsizes(X)
    rec_con = conform_dims(dimX,rec,ispan(1,dimsizes(dimX)-1,1))
    ts_con = conform_dims(dimX,ts,0)
    Xd=X-rec_con*ts_con
    copy_VarCoords(X, Xd)
  end if
  if(isatt(X,"name") .and. isatt(ts,"name"))
    Xd@name = X@name+"-"+ts@name
  end if
  return(Xd)
end

undef("designal") ; FX| designal
function designal(X,ts)
local rec,dim_rec,Xd,dimX,temTs,temX,rec_con,ts_con,type,tem
begin
  type = typeof(ts)
  if(type .eq. "list")then
    dimList = ListCount(ts)
    temX = _designal(X,ts[0])
    if(dimList .eq. 1)then
      return temX
    end if
    temTs = _designal(ts[1],ts[0])
    temX = _designal(temX,temTs)
    if(dimList .eq. 2)then
      return temX
    end if
    return temX
  end if
  return _designal(X,ts)
end

undef("smart_notify")
procedure smart_notify(wks,ts,type,opt)
  begin
  print("----------------------------------------------------")
  print("in wks: "+wks@name)
  print("----------------------------------------------------")
end

undef("setDefaultAtt")
procedure setDefaultAtt(res, att:string, default)
local list_size
begin
  if(isatt(res,att)) return(0) end if
  if(typeof(default) .eq. "list")
    list_size = ListCount(default)
    do i = 0, list_size-1, 1
      var := default[i]
      if(any(ismissing(var))) continue
      else 
        res@$att$ = var
        break
      end if
    end do
  else
    res@$att$ = default
  end if
end



undef("setDefaultAtts")
procedure setDefaultAtts(res:logical, atts[*]:string, defaults:list)
local list_size,i
begin
  if(dimsizes(atts) .ne. ListCount(defaults))
    print("size of atts must equal to defaults")
    return(0)
  end if
  list_size = ListCount(defaults)
  do i = 0, list_size-1, 1
    if(isatt(res,atts(i))) 
      continue
    else 
      res@$atts(i)$ =defaults[i]
    end if
  end do
end

undef("setExistAtt")
procedure setExistAtt(res:logical, att:string, default)
local list_size,i,var
begin
  if(.not. isatt(res,att)) return(0) end if
  if(typeof(default) .eq. "list")
    list_size = ListCount(default)
    do i = 0, list_size-1, 1
      var := default[i]
      if(ismissing(var))
        continue
      else 
        res@$att$ := var
        break
      end if
    end do
  else
    res@$att$ := default
  end if
end

undef("is_element")
function is_element(element[1],array[*])
local tem,test
begin
  tem = ind(array .eq. element)
  test = .not. isatt(tem,"_FillValue")
  test@ind = tem
  return(test)
end

undef("get_element")
function get_element(element[1],array[*],selection[*])
local tem,test
begin
  tem = ind(array .eq. element)
  if(isatt(tem,"_FillValue"))
    print_error("the element: '"+element+"' is not found in given array")
    test = False
  else
    test = selection(tem)
    test@location = tem
  end if
  return(test)
end

undef("gen")
function gen(att:string)
begin
  atts = (/"clim","anom","stddev","trend","std"/)
  if(is_element(att,atts))
    res = True
    res@method = att
    return(res)
  end if
  atts := (/"NH","SH"/)
  if(is_element(att,atts))
    res_ind = ind(atts .eq. att)
    ranges = (/(/0,90,0,360/),(/-90,0,0,360/)/)
    return(ranges(res_ind,:))
  end if
  if(att .eq. "tem_file")
    fileName = localpath(1)+"plot_tem/tem"
    return(fileName)
  end if
  if(att .eq. "pdf")
    fig = "pdf"
    fig@wkPaperWidthF = 20
    fig@wkPaperHeightF = 20
    return(fig)
  end if
end


undef("last")
function last (var[*])
begin
  return(var(dimsizes(var)-1))
end

undef("get_tval")
function get_tval (trend)
local tval
begin
  tval = reshape(trend@tval, dimsizes(trend))
  copy_VarCoords(trend, tval)
  tval@_FillValue = trend@_FillValue
  return(tval)
end

undef("get_yintercept")
function get_yintercept (trend)
begin
  yintercept = reshape(trend@yintercept, dimsizes(trend))
  copy_VarCoords(trend, yintercept)
  yintercept@_FillValue = trend@_FillValue
  return(yintercept)
end

undef("concat")
function concat(var:list)
local count,isdimed,i,dimName
begin
  count = ListCount(var)
  ; print(dim)
  isdimed = False
  do i = 0, count-1
    copy_VarAtts(var[i],var); copy atts from every element in the list
    if(isdimnamed(var[i],0))
      dimName := getvardims(var[i])
      isdimed = True
    end if
  end do
  ListSetType(var,"cat")
  new_var = var[:]
  copy_VarAtts(var,new_var)
  if(isdimed)
    dim = dimsizes(dimName)
    do i = 0, dim-1
      new_var!i = dimName(i)
    end do 
  end if
  return(new_var)
end

undef("isArray")
function isArray (var)
local dim,ndim
begin
  dim = dimsizes(var)
  ndim = dimsizes(dim)
  if(ndim .eq. 1)
    return dim .ne. 1
  end if
  return True
end


undef("append")
function append (var,tem)
local new_var,hasString,hasNumeric,isMix,tem_list
begin
  if(.not. isArray(var) .and. ismissing(var))
    if(typeof(tem) .eq. "list")
      new_var = tem[:]
    else
      new_var = tem
    end if
    return new_var
  end if

  if(typeof(tem) .eq. "list")
    ListPush(tem, var)
    ListSetType(tem, "cat")
    new_var = tem[:]
  else
    hasString = isstring(var) .or. isstring(tem)
    hasNumeric = isnumeric(var) .or. isnumeric(tem)
    isMix = hasString .and. hasNumeric
    if(isMix)then
      if(isnumeric(var))then
        var_str = totype(var, "string")
        tem_list = [/var_str,tem/]
      end if
      if(isnumeric(tem))then
        tem_str = totype(tem, "string")
        tem_list = [/var,tem_str/]
      end if
    else
      tem_list = [/var,tem/]
    end if
    ListSetType(tem_list, "cat")
    new_var = tem_list[:]
  end if
  copy_VarAtts(var,new_var)
  ; if(dimsizes(dimsizes(var) .ne. 1))
  copy_VarCoords_not_n(var,new_var,0)
return(new_var)
end

undef("append_time")
function append_time(time,time_to_append)
begin
  new_time = time_to_newtime(time_to_append,time@units)
  time_list = [/time,new_time/]
  ListSetType(time_list, "cat")
  new_time := time_list[:]
  new_time!0 = "time"
  new_time&time =  new_time
  copy_VarAtts(time,new_time)
return(new_time)
end



undef("get_res_value_with_index")
function get_res_value_with_index (res:logical, att:string, index:integer, default)
begin
  att_value = get_res_value_keep(res, att, default)
  dim_att = dimsizes(att_value)
  if(index .lt. dim_att)
    return(att_value(index))
  else
    if(dim_att .ne. 1)
      printc("the index is larger than size of the attribute, using the last element: "+att_value(dim_att-1),True)
    end if
    return(att_value(dim_att-1))
  end if
end

undef("delete_attrs")
procedure delete_attrs(res:logical,att_name:string)
local i
begin
  do i = 0, dimsizes(att_name)-1
    if(isatt(res,att_name(i)))
      delete(res@$att_name(i)$)
    end if
  end do
end

undef("copy_res_eq_with_index")
procedure copy_res_eq_with_index(res_from:logical, res_to:logical, att:string, index:integer)
local atts,atts_name,att_value,dim_att,isAttArray,index,i
begin 
  atts = get_res_eq(res_from, att)
  atts_name = getvaratts(atts)
  do i = 0, dimsizes(atts_name)-1
    ; print(atts_name)
    ; print(atts_name(i))
    if( .not. isatt(res_from,atts_name(i)))
      continue
    end if

    if( atts_name(i) .eq. "lbLabelStrings") then
      continue
    end if
    att_value := res_from@$atts_name(i)$
    isAttArray = isArray(att_value)
    dim_att = dimsizes(att_value)
    if(isAttArray) then
      ; print(atts_name(i))
      ; print(att_value)
      if(index .lt. dim_att)
        res_to@$atts_name(i)$ := att_value(index)
        ; print(res_to@$atts_name(i)$)
        ; print(att_value(index))
        ; set_attr(tem, atts(i),att_value(index))
      else
        printc("the index is larger than size of the attribute, using the last element: "+att_value(dim_att-1),"red")
        res_to@$atts_name(i)$ := att_value(dim_att-1)
        ; set_attr(tem, atts(i),att_value(dim_att-1))
      end if
    else
      res_to@$atts_name(i)$ := att_value

      ; set_attr(tem, atts(i),att_value)
    end if
  end do
end
; undef("append")
; function append (var, tem)
; begin
;   ; dim_pad_extend(x, nExt, dims, opt)
;   if(typeof(tem) .eq. "list")
;     x = tem[0]
;     count = ListCount(tem)
;     simple_mode = (count .eq. 1)
;   else
;     x = tem
;     simple_mode = True
;   end if
;   type_var = typeof(var)
;   dim_var = dimsizes(var)
;   if(simple_mode)
;     dim_new = dim_var+dimsizes(x)
;     var_new = dim_pad_extend(var,dim_new,0,False)
;     var_new(dim_var:) = x
;   else
;     dim_new = dim_var
;     do i = 0, count -1
;       dim_new = dim_new+dimsizes(tem[i])
;     end do
;     var_new = dim_pad_extend(var,dim_new,0,False)
;     dim_start = dim_var
;     do i = 0, count -1
;       dim_end = dim_start+dimsizes(tem[i])
;       var_new(dim_start:dim_end-1) = tem[i]
;       dim_start = dim_end
;     end do
;   end if
;   return(var_new)
; end


; undef("merge_1d")
; function merge_1d (var_list:list)
; begin
;   count = ListCount(var_list)
;   var0 = var_list[0]
;   dim0 = dimsizes(var0)
;   type = typeof(var0)
;   do i = 1, count-1
;     var_tem = var_list[i]
;     dim_tem = dimsizes(var_list[i])
;     dim_new = dim0+dim_tem
;     tem = new(dim_new,type)
;     tem(:dim0-1) = var0
;     tem(dim0:) = var_tem
;     var0 := tem
;     dim0 := dim_new
;   end do
; return(var0)
; end


undef("latWeight")
function latWeight(X)
local lat_list,isLat,lat_name,wgt,dimName,Xw
begin
  lat_list = (/"lat","Lat","latitude","Latitude"/);可能的纬度名
  isLat = isdim(X,lat_list); 判断X中是否存在纬度
  lat_name = lat_list(ind(isLat)) ;获得纬度名
  sqrtWeight = get_res_value_keep(X, "sqrt", False)
  if(sqrtWeight)then
    wgt := sqrt(cos(X&$lat_name$*0.01745329));获得权重
  else
    wgt := cos(X&$lat_name$*0.01745329);获得权重
  end if
  dimName = getvardimnames(X)
  Xw := X*conform(X, wgt, ind(dimName .eq. lat_name)); 加权
  copy_VarCoords(X, Xw)
  return Xw
end


; begin
;   dimName = (/"year","lat","lon","level"/)
;   dim = "lat"
;   order = 3
;   newvar = changeDimOrder(dimName,dim,order)
;   print(newvar)
; end
undef("setNatureMode")
procedure setNatureMode (res)
  begin
  res@gsnLeftString = ""
  res@gsnRightString = ""
  res@gsnStringBold = True
  res@gsnLeftStringFontHeightF = get_res_value_keep(res,"gsnLeftStringFontHeightF", 0.025)
  res@tiYAxisOffsetXF = get_res_value_keep(res,"tiYAxisOffsetXF", 0.025)
end

undef("setLabelbarTitle");FX| 设置色标标题
  procedure setLabelbarTitle (res,title)
  begin
  res@lbTitleString = title
  res@lbTitleOn = True
  res@lbTitleExtentF = 0.2
  ; res@lbOrientation       = get_res_value_keep(res,"lbOrientation","Horizontal")
  setDefaultAtt(res,"lbOrientation","Horizontal")
  ; if(.not. isatt(res,"lbTitleFontHeightF"))
  ;   res@lbTitleFontHeightF = res@lbLabelFontHeightF
  ; end if
  setDefaultAtt(res,"lbTitleFontHeightF",res@lbLabelFontHeightF)
  ; if(.not. isatt(res,"lbTitleOffsetF"))
  ;   res@lbTitleOffsetF = 0.2
  ; end if
  setDefaultAtt(res,"lbTitleOffsetF",0.2)
  if(res@lbOrientation .eq. "Vertical")
    ; res@lbTitlePosition = get_res_value_keep(res,"lbTitlePosition","right")
    setDefaultAtt(res,"lbTitlePosition","right")
    res@lbTitleDirection = "across"
    res@lbTitleAngleF = 270
  else
    ; res@lbTitlePosition = get_res_value_keep(res,"lbTitlePosition","bottom")
    setDefaultAtt(res,"lbTitlePosition","bottom")
    res@lbTitleDirection = "across"
    res@lbTitleAngleF = 0
    ; res@pmLabelBarOrthogonalPosF = res@pmLabelBarOrthogonalPosF+0.1
    if(res@lbTitlePosition .eq. "right")
      res@lbTitleExtentF = 0.01
      res@lbTitleOffsetF = 0.1
      ; res@pmLabelBarOrthogonalPosF = res@pmLabelBarOrthogonalPosF-0.1
    end if
    if(res@lbTitlePosition .eq. "left")
      res@lbTitleExtentF = 0.1
      res@lbTitleOffsetF = 0.1
    end if
  end if
end

undef("setLabelbar");FX| 设置色标
procedure setLabelbar (res)
  begin
      ; resp@lbOrientation = "Horizontal"
  res@lbLabelBarOn        = True
  res@lbBoxLineColor = "black"; "white"
  res@lbLabelFontHeightF  = get_res_value_keep(res,"lbLabelFontHeightF",0.03)
  ; res@lbBoxEndCapStyle    = "" ;get_res_value_keep(res,"lbStyle","TriangleBothEnds")
  res@lbOrientation       = get_res_value_keep(res,"lbOrientation","Horizontal")
  res@lbBoxEndCapStyle = "RectangleEnds"
end
;tag
;todo
;fig
undef("sin_dg")
function sin_dg(degree)
  begin
  result = sin(degree*get_d2r("float"))
  ; result = sin(degree/180.0*get_pi("float"))
  return(result)
end
undef("cos_dg")
function cos_dg(degree)
  begin
  result = cos(degree*get_d2r("float"))
  ; result = cos(degree/180.0*get_pi("float"))
  return(result)
end
undef("cd_calendar_fix")
function cd_calendar_fix(time, option)
begin
  if(typeof(time) .eq. "int64")
    time_int = toint(time)
    copy_VarAtts(time,time_int)
    return(cd_calendar(time_int, option))
  end if
  return(cd_calendar(time,option))
end

undef("add_YRAxisString") ; FX| add_YRAxisString
procedure add_YRAxisString (plotid,text:string,opt)
local tmp_wks,anno,amJust,amParallelPosF,amOrthogonalPosF
begin
  tmp_wks = NhlGetParentWorkstation(plotid)
    rightaxis_string = create "right_axis" textItemClass tmp_wks
      "txString"      : text
      "txFontHeightF" : get_res_value_keep(opt, "tiYRAxisStringFontHeightF",0.05)
      "txFontColor"   : get_res_value_keep(opt, "tiYRAxisFontColor","black")
      "txAngleF"      : 270.
    end create
    anno = NhlAddAnnotation(plotid,rightaxis_string)
    amParallelPosF = get_res_value_keep(opt,"tiYRAxisOffsetXF",0.03)
    amOrthogonalPosF = get_res_value_keep(opt,"tiYRAxisOffsetYF",0.5)
    setvalues anno
      "amZone"          : 3      ; Just outside plot area
      "amJust"          : "centercenter"
      "amSide"          : "right" 
      "amParallelPosF"  : amOrthogonalPosF
      "amOrthogonalPosF": amParallelPosF
      "amResizeNotify"  : True     ; Resize if plot resized.
    end setvalues
  ; return(anno)
end

undef("add_YLAxisString") ; FX| add_YLAxisString
procedure add_YLAxisString (plotid,text:string,opt)
  begin
  tmp_wks = NhlGetParentWorkstation(plotid)
    rightaxis_string = create "right_axis" textItemClass tmp_wks
      "txString"      : text
      "txFontHeightF" : get_res_value_keep(opt, "txFontHeightF",0.05)
      "txFontColor"   : get_res_value_keep(opt, "txFontColor","black")
      "txAngleF"      : 90.
    end create

    anno = NhlAddAnnotation(plotid,rightaxis_string)
    
    setvalues anno
      "amZone"          : 3      ; Just outside plot area
      "amJust"          : "centercenter"
      "amSide"          : "left" 
      "amParallelPosF"  : 0.5
      "amOrthogonalPosF": 0.05-get_res_value_keep(opt, "tiYlOffsetXF",0.)
      "amResizeNotify"  : True     ; Resize if plot resized.
    end setvalues
end

undef("add_XBAxisString") ; FX| add_XBAxisString
procedure add_XBAxisString (plotid,text:string,opt)
  begin
  tmp_wks = NhlGetParentWorkstation(plotid)
    rightaxis_string = create "right_axis" textItemClass tmp_wks
      "txString"      : text
      "txFontHeightF" : get_res_value_keep(opt, "txFontHeightF",0.035)
      "txFontColor"   : get_res_value_keep(opt, "txFontColor","black")
      "txAngleF"      : 0.
    end create

    anno = NhlAddAnnotation(plotid,rightaxis_string)
    
    setvalues anno
      "amZone"          : 3      ; Just outside plot area
      "amJust"          : "centercenter"
      "amSide"          : "bottom" 
      "amParallelPosF"  : get_res_value_keep(opt, "tiXBOffsetXF",0.5)
      "amOrthogonalPosF": get_res_value_keep(opt, "tiXBOffsetYF",0.)
      "amResizeNotify"  : True     ; Resize if plot resized.
    end setvalues
end


undef("add_LeftString") ; FX| add_LeftString
procedure add_LeftString (plotid,text:string,opt)
  begin
  tmp_wks = NhlGetParentWorkstation(plotid)
  ; tmp_wks = NhlGetParentWorkstation(tem)
  rightaxis_string = create "right_axis" textItemClass tmp_wks
    "txString"      : text
    "txFontHeightF" : get_res_value_keep(opt, "gsnLeftStringFontHeightF",0.035)
    "txFontColor"   : get_res_value_keep(opt, "txFontColor","black")
    "txAngleF"      : 0.
    "txFont"        : where(get_res_value_keep(opt,"gsnStringBold",False),22,21)
  end create
  anno = NhlAddAnnotation(plotid,rightaxis_string)
    
  setvalues anno
    "amZone"          : 3      ; Just outside plot area
    "amJust"          : "TopLeft"
    "amSide"          : "top" 
    "amParallelPosF"  : get_res_value_keep(opt, "gsnLeftOffsetXF",0.)
    "amOrthogonalPosF": 0.05+get_res_value_keep(opt, "gsnLeftOffsetYF",0.)
    "amResizeNotify"  : True     ; Resize if plot resized.
  end setvalues
end

undef("add_RightString") ; FX| add_RightString
procedure add_RightString (plotid:graphic,text:string,opt)
  begin
  tmp_wks = NhlGetParentWorkstation(plotid)
  RightString = create "RightString" textItemClass tmp_wks
    "txString"      : text
    "txFontHeightF" : get_res_value_keep(opt, "gsnRightStringFontHeightF",0.035)
    "txFontColor"   : get_res_value_keep(opt, "txFontColor","black")
    "txAngleF"      : 0.
    "txFont"        : where(get_res_value_keep(opt,"gsnStringBold",False),22,21)
  end create

  anno = NhlAddAnnotation(plotid,RightString)
  
  setvalues anno
    "amZone"          : 3      ; Just outside plot area
    "amJust"          : "TopRight"
    "amSide"          : "top" 
    "amParallelPosF"  : 0.95+get_res_value_keep(opt, "gsnRightOffsetXF",0.)
    "amOrthogonalPosF": 0.05+get_res_value_keep(opt, "gsnRightOffsetYF",0.)
    "amResizeNotify"  : True     ; Resize if plot resized.
  end setvalues
end

undef("add_CornerString") ; FX| add_CornerString
procedure add_CornerString (plotid,text:string)
local tmp_wks,CornerString,anno
begin
  tmp_wks = NhlGetParentWorkstation(plotid)
  CornerString = create "CornerString" textItemClass tmp_wks
    "txString"      : text
    "txFontHeightF" : get_res_value_keep(text, "gsnCornerStringFontHeightF",0.035)
    "txFontColor"   : get_res_value_keep(text, "txFontColor","black")
    "txAngleF"      : 0.
    "txFont"        : 22
  end create

    anno = NhlAddAnnotation(plotid,CornerString)
    
  setvalues anno
    "amZone"          : 3      ; Just outside plot area
    "amJust"          : "topleft"
    "amSide"          : "top" 
    "amParallelPosF"  : -0.1+get_res_value_keep(text, "gsnCornerOffsetXF",0.)
    "amOrthogonalPosF": 0.05+get_res_value_keep(text, "gsnCornerOffsetYF",0.)
    "amResizeNotify"  : True     ; Resize if plot resized.
  end setvalues
end

undef("set_XBTick")
procedure set_XBTick(res,dim:string)
begin
  res@tmXBMode = "Explicit"
  if(typeof(res@tmXBTickSpacingF) .eq. "float")
    spacing = floattointeger(res@tmXBTickSpacingF)
  else
    spacing = res@tmXBTickSpacingF
  end if
  startF = get_res_value_keep(res,"tmXBTickStartF",0)
  endF = get_res_value_keep(res,"tmXBTickEndF",360)
  res@tmXBValues = ispan(startF,endF,spacing)
  if(is_element(dim,(/"lon","Lon","Longitude","longtude"/)))
    unit = where(res@tmXBValues .lt. 0, -res@tmXBValues+"W",res@tmXBValues+"")
    unit = where(res@tmXBValues .gt. 180, 360-res@tmXBValues+"W",unit)
    unit = where(res@tmXBValues .gt. 0 .and. res@tmXBValues .lt. 180,res@tmXBValues+"E",unit )
  else if(is_element(dim,(/"lat","Lat","latitude","Latitude"/)))
    unit = where(res@tmXBValues .lt. 0, -res@tmXBValues+"S",res@tmXBValues+"")
    unit = where(res@tmXBValues .gt. 0, res@tmXBValues+"N",unit)
  else
    unit = res@tmXBValues
  end if
  end if
  res@tmXBLabels = unit
end

undef("regCoef_n_Wrap")
function regCoef_n_Wrap(x[*],y,dims_y[1])
  begin
  if(typeof(dims_y) .eq. "string")
    dimName = getvardims(y)
    ind_str = ind(dimName .eq. dims_y)
    reg = regCoef_n(x,y,0,ind_str)
    copy_VarCoords_not_n(y,reg,ind_str)
  else
    reg = regCoef_n(x,y,0,dims_y)
    copy_VarCoords_not_n(y,reg,dims_y)
  end if
  return(reg)
end

undef("escorc_n_Wrap")
function escorc_n_Wrap(x[*],y,dims_y[1])
  begin
  if(typeof(dims_y) .eq. "string")
    dimName = getvardims(y)
    ind_str = ind(dimName .eq. dims_y)
    cor = escorc_n(x,y,0,ind_str)
    copy_VarCoords_not_n(y,cor,ind_str)
  else
    cor = escorc_n(x,y,0,dims_y)
    copy_VarCoords_not_n(y,cor,dims_y)
  end if
  return(cor)
  
end


undef ("dim_avg_n_Wrap")
function dim_avg_n_Wrap (x:numeric,dim_args[*])
local xave,dims,var_dimsizes,i
  begin
  if(typeof(dim_args) .eq. "string")
    dims = ind_dev(getvardims(x),dim_args)
  else
    var_dimsizes = dimsizes(dimsizes(x))
    dims = ind_dev(ispan(0,var_dimsizes-1,1),dim_args)
  end if
  if(ismissing(dims(0))) return(x) end if
  xave = dim_avg_n(x,dims(0))
  if(dimsizes(dims) .gt. 1)
    do i = 1, dimsizes(dims)-1,1
      xave := dim_avg_n(xave,dims(i)-i)
    end do
  end if
  copy_VarAtts(x,xave)
  copy_VarCoords_not_n (x, xave, dims)
                                         ; add an extra attribute
  xave@average_op_ncl = dimWrapString("dim_avg_n",x,dims)
  return (xave)
end

undef ("dim_max_n_Wrap")
function dim_max_n_Wrap (x:numeric,dim_args[*])
local xave,dims,var_dimsizes,i
  begin
  if(typeof(dim_args) .eq. "string")
    dims = ind_dev(getvardims(x),dim_args)
  else
    var_dimsizes = dimsizes(dimsizes(x))
    dims = ind_dev(ispan(0,var_dimsizes-1,1),dim_args)
  end if
  if(ismissing(dims(0))) return(x) end if
  xave = dim_max_n(x,dims(0))
  if(dimsizes(dims) .gt. 1)
    do i = 1, dimsizes(dims)-1,1
      xave := dim_max_n(xave,dims(i)-i)
    end do
  end if
  copy_VarAtts(x,xave)
  copy_VarCoords_not_n (x, xave, dims)
                                         ; add an extra attribute
  xave@average_op_ncl = dimWrapString("dim_max_n",x,dims)
  return (xave)
end

undef ("dim_min_n_Wrap")
function dim_min_n_Wrap (x:numeric,dim_args[*])
local xave,dims,var_dimsizes,i
  begin
  if(typeof(dim_args) .eq. "string")
    dims = ind_dev(getvardims(x),dim_args)
  else
    var_dimsizes = dimsizes(dimsizes(x))
    dims = ind_dev(ispan(0,var_dimsizes-1,1),dim_args)
  end if
  if(ismissing(dims(0))) return(x) end if
  xave = dim_min_n(x,dims(0))
  if(dimsizes(dims) .gt. 1)
    do i = 1, dimsizes(dims)-1,1
      xave := dim_min_n(xave,dims(i)-i)
    end do
  end if
  copy_VarAtts(x,xave)
  copy_VarCoords_not_n (x, xave, dims)
                                         ; add an extra attribute
  xave@average_op_ncl = dimWrapString("dim_min_n",x,dims)
  return (xave)
end

undef ("dim_sum_n_Wrap")
function dim_sum_n_Wrap (x:numeric,dim_args[*])
local xave, dims,var_dimsizes,i
begin
  if(typeof(dim_args) .eq. "string")
    dims = ind_dev(getvardims(x),dim_args)
  else
    var_dimsizes = dimsizes(dimsizes(x))
    dims = ind_dev(ispan(0,var_dimsizes-1,1),dim_args)
  end if
  if(ismissing(dims(0))) return(x) end if
  xave = dim_sum_n(x,dims(0))
  if(dimsizes(dims) .gt. 1)
    do i = 1, dimsizes(dims)-1,1
      xave := dim_sum_n(xave,dims(i)-i)
    end do
  end if
  copy_VarAtts(x,xave)

  copy_VarCoords_not_n (x, xave, dims)
                                         ; add an extra attribute
  xave@average_op_ncl = dimWrapString("dim_sum_n",x,dims)

  return (xave)
end

undef ("dim_rmvmean_n_Wrap")
function dim_rmvmean_n_Wrap(x:numeric,dim_arg[1])
local dims,dim,x_rmvmean
begin 
  if(typeof(dim_arg) .eq. "string")
    dims = getvardims(x)
    dim = ind(dims .eq. dim_arg)
    ; dim = ind_dev(getvardims(x),dim_arg)
  else
    ; var_dimsizes = dimsizes(dimsizes(x))
    ; dim = ind_dev(ispan(0,var_dimsizes-1,1),dim_arg)
    dim = dim_arg
  end if
  x_rmvmean = dim_rmvmean_n(x,dim)
  copy_VarAtts(x,x_rmvmean)

  copy_VarCoords(x, x_rmvmean)
  if (isatt(x,"long_name")) then
      x_rmvmean@long_name = "Anomalies: "+getLongName(x)
  else
      x_rmvmean@long_name = "Deviation from mean"
  end if

  x_rmvmean@rmvmean_op_NCL = dimWrapString("dim_rmvmean_n",x,dim)

  return (x_rmvmean)
end


undef ("copy_VarCoords_not_n_to")
procedure copy_VarCoords_not_n_to(var_from,var_to,dims_to_skip)
local dimt, dimf, rfrom, rto, i, ifrom, ito, dName, ndims, dims
begin                      
  dimf  = dimsizes(var_from)            
  dimt  = dimsizes(var_to)
  rfrom = dimsizes(dimf)      ; rank of var_from
  rto   = dimsizes(dimt)      ; rank of var_to
  ndims = dimsizes(dims_to_skip)

;---Error checking for "dims_to_skip"
  if(any(dims_to_skip.lt.0.or.dims_to_skip.gt. dimsizes(dimf))) then
    print("Error: copy_VarCoords_not_n: invalid dimensions to skip")
    return
  end if

;---Error checking for rank
  if((rfrom-ndims).gt.rto) then
    print("Error: copy_VarCoords_not_n: you are not skipping enough dimensions.")
    return
  end if

  dName = getvardims(var_from)

  ; ito = 0     ; leftmost dimension of var_to array
  ifrom = 0
  if (.not.all(ismissing(dName))) then
    do i = 0,rto-1
      if(.not.any(i.eq.dims_to_skip)) then
        ito = i
        if (.not.ismissing(dName(ifrom)).and.dimf(ifrom).eq.dimt(ito)) then  
          var_to!ito = var_from!ifrom
          if(iscoord(var_from,var_from!ifrom))
            var_to&$var_to!ito$ = var_from&$var_from!ifrom$
          end if
        end if
        ifrom = ifrom + 1
      else
        if(rfrom.eq.rto) then
          ifrom = ifrom + 1
        end if
      end if
    end  do
  end if
end




undef("get_att_eq")
function get_att_eq(var,prefix:string)
local i, j, ret_res, attnames
begin
  attnames = getvaratts(var)
  if(any(ismissing(attnames))) return(False) end if
  ret_res = True
  do i = 0,dimsizes(prefix)-1
    att_match := str_match_regex(attnames,"^"+prefix(i))
    do j = 0,dimsizes(att_match)-1
      ret_res@$att_match(j)$ = var@$att_match(j)$
    end do
  end do
  return(ret_res)
end

undef("get_att_ne")
function get_att_ne(var,prefix:string)
local i, j, ret_res, attnames
begin
  attnames = getvaratts(var)
  if(any(ismissing(attnames))) return(False) end if
  ret_res = True
  str_ind = new(dimsizes(prefix),integer)
  is_ind = new(dimsizes(prefix),logical)
  do i = 0,dimsizes(attnames)-1
    do j = 0,dimsizes(prefix)-1
      str_ind(j) = str_index_of_substr(attnames(i),prefix(j),1)
      is_ind(j) = (.not. ismissing(str_ind(j))) .and. (str_ind(j) .eq. 0)
    end do
    if(.not. any(is_ind))
      ret_res@$attnames(i)$ = var@$attnames(i)$
    end if
  end do
  return(ret_res)
end

undef("get_att_match")
function get_att_match(var,Include:string,Exclude:string)
local i, j, ret_res, attnames
begin
  ret_res = True
  attnames = getvaratts(var)
  str_ind = new(dimsizes(Exclude),integer)
  is_ind = new(dimsizes(Exclude),logical)
  if(any(ismissing(attnames))) return(0) end if
  do i = 0,dimsizes(Include)-1
    att_match := str_match_regex(attnames,"^"+Include(i))
    do j = 0,dimsizes(att_match)-1
      do k = 0,dimsizes(Exclude)-1
        str_ind(k) = str_index_of_substr(att_match(j),Exclude(k),1)
        is_ind(k) = (.not. ismissing(str_ind(k))) .and. (str_ind(k) .eq. 0)
      end do
      if(.not. any(is_ind))
        ret_res@$att_match(j)$ = var@$att_match(j)$
      end if
    end do
  end do
  return(ret_res)
end

undef("copy_VarAtts_eq")
procedure copy_VarAtts_eq(var_from,var_to, Include[*]:string) 
local attnames,i,j
begin
  attnames = getvaratts(var_from)
  if(any(ismissing(attnames))) return(0) end if
  do i = 0,dimsizes(Include)-1
    att_match := str_match_regex(attnames,"^"+Include(i))
    if(any(ismissing(att_match))) continue end if
    do j = 0,dimsizes(att_match)-1
      var_to@$att_match(j)$ := var_from@$att_match(j)$
    end do
  end do
end

undef("copy_VarAtts_ne")
function copy_VarAtts_ne(var_from,var_to, Exclude[*]:string) 
local attnames,str_ind,is_ind,i,j
begin
  attnames = getvaratts(var_from)
  if(any(ismissing(attnames))) return(0) end if
  str_ind = new(dimsizes(Exclude),integer)
  is_ind = new(dimsizes(Exclude),logical)
  do i = 0,dimsizes(attnames)-1
    do j = 0,dimsizes(Exclude)-1
      str_ind(j) = str_index_of_substr(attnames(i),Exclude(j),1)
      is_ind(j) = (.not. ismissing(str_ind(j))) .and. (str_ind(j) .eq. 0)
    end do
    if(.not. any(is_ind))
      var_to@$attnames(i)$ := var_from@$attnames(i)$
    end if
  end do
end

undef("copy_VarAtts_match")
procedure copy_VarAtts_match(var_from, var_to, Include:string, Exclude:string) 
local attnames,str_ind,is_ind,i,att_match,j,k
begin
  attnames = getvaratts(var_from)
  str_ind = new(dimsizes(Exclude),integer)
  is_ind = new(dimsizes(Exclude),logical)
  if(any(ismissing(attnames))) return(0) end if
  do i = 0,dimsizes(Include)-1
    att_match := str_match_regex(attnames,"^"+Include(i))

    ; print(att_match)
    if(any(ismissing(att_match))) continue end if
    do j = 0,dimsizes(att_match)-1
      do k = 0,dimsizes(Exclude)-1
        str_ind(k) = str_index_of_substr(att_match(j),Exclude(k),1)
        is_ind(k) = (.not. ismissing(str_ind(k))) .and. (str_ind(k) .eq. 0)
      end do
      if(.not. any(is_ind))
        var_to@$att_match(j)$ := var_from@$att_match(j)$
      end if
    end do
  end do
end

undef("get_month") 
function get_month(month:integer)
local month_names,month_abs,tem,ind_neg
begin
  month_names = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
  if(any(month .lt. 0))
    month_abs = abs(month)-1
    tem = month_names(month_abs)
    ind_neg = ind(month .lt. 0)
    tem(ind_neg) = tem(ind_neg)+"(-1)"
  else
    tem = month_names(month-1)
  end if
  return tem
end

undef("get_month_abbrev") 
function get_month_abbrev(month:integer)
local month_names,month_abs,tem,ind_neg
begin
  month_names = (/"J","F","M","A","M","J","J","A","S","O","N","D"/)
  isMarkPrev = get_res_value_keep(month,"markPrev",False)
  if(any(month .lt. 0))
    month_abs = abs(month)-1
    tem = month_names(month_abs)
    if(isMarkPrev)then
      ind_neg = ind(month .lt. 0) 
      tem(ind_neg) = tem(ind_neg)+"(-1)"
    end if
  else
    tem := month_names(month-1)
  end if
  return str_concat(tem)
end

undef("changeDimOrder")
function changeDimOrder(var,dim,order)
local dimName,dim_ind,dim_new,tem,operater,dims
begin
  dimName = getvardims(var)
  ; dimName = var
  dim_ind = ind(dimName .eq. dim)
  if(ismissing(dim_ind)) 
    dim_new = append(1,dimsizes(var))
    tem = reshape(var,dim_new)
    copy_VarCoords_not_n_to(var,tem,0)
    ; copy_VarAtts(var,tem)
    return(tem) 
  end if
  if(order .eq. dim_ind) return(var) end if
  do while(order .ne. dim_ind)
    if(order .lt. dim_ind)
      operater = dim_ind -1
    else if(order .gt. dim_ind)
      operater = dim_ind + 1
    end if
    end if
    tem = dimName(operater)
    dimName(operater) = dim
    dimName(dim_ind) = tem
    dim_ind = ind(dimName .eq. dim)
  end do
  dims = dimsizes(dimName)
  if(dims .eq. 2)
    return var($dimName(0)$|:,$dimName(1)$|:)
  end if
  if(dims .eq. 3)
    return var($dimName(0)$|:,$dimName(1)$|:,$dimName(2)$|:)
  end if
  if(dims .eq. 4)
    return var($dimName(0)$|:,$dimName(1)$|:,$dimName(2)$|:,$dimName(3)$|:)
  end if
  if(dims .eq.5)
    return var($dimName(0)$|:,$dimName(1)$|:,$dimName(2)$|:,$dimName(3)$|:,$dimName(4)$|:)
  end if
end

undef("isList")
function isList(var)
begin
  return(typeof(var) .eq. "list")
end


undef("renameDim")
procedure renameDim (vars,oldDimName, newDimName)
local count,i,dim_ind
begin
  if(isList(vars))
    count = ListCount(vars)
    do i = 0, count-1
      ; tem = vars[i]
      if(isdim(vars[i],oldDimName))
        dim_ind = ind(getvardims(vars[i]) .eq. oldDimName)
        vars[i]!dim_ind = newDimName
      end if
    end do
  elseif(isdim(vars, oldDimName))
    dim_ind = ind(getvardims(vars) .eq. oldDimName)
    vars!dim_ind = newDimName
  end if
end


undef("merge")
function merge (varList:list,dimName,dimVar)
local count,tem,tem_list,i,var
begin
  count = ListCount(varList)
  tem = changeDimOrder(varList[0],dimName,0)
  tem_list = [/tem/]
  do i = 1, count-1
    ListAppend(tem_list,changeDimOrder(varList[i],dimName,0))
  end do
  ListSetType(tem_list,"cat")
  var = tem_list[:]
  copy_VarCoords_not_n_to(tem,var,0)
  var!0 = dimName
  var&$dimName$ = dimVar
  return(var)
end

; undef("printMinMax")
; procedure printMinMax (x:numeric)  
; ;  Usage:   printMinMax (T,True)                   
; begin                                             
;           ; attribute names to check             
;    vLongName = (/"long_name", "description", "standard_name" /)
;    vUnits    = get_valid_units()
;    long_name = ""        
;    units     = ""
;    do n=0,dimsizes(vLongName)-1            
;       if (isatt(x,vLongName(n))) then     
;           long_name = x@$vLongName(n)$   
;           break
;       end if
;    end do
; ; Don't bother with units if long_name doesn't exist
;    if(long_name.ne."") then
;      do n=0,dimsizes(vUnits)-1            
;         if (isatt(x,vUnits(n))) then     
;             units = x@$vUnits(n)$   
;             break
;         end if
;      end do
;    end if  
                  
;    if (long_name.ne."") then
;       if(units.ne."") then 
;         print (long_name+ " ("+units+")" + " : min="+min(x)+"   max="+max(x)) 
;       else
;         print (long_name+ " : min="+min(x)+"   max="+max(x)) 
;       end if
;    else 
;        print ("min="+min(x)+"   max="+max(x))
;    end if 
; end
undef("getRefer")
function getRefer(id)
local tem
begin
  tem = id
  return tem
end

undef("setBufferPath")
procedure setBufferPath(path)
local i,id,f
begin
  bufferPath = path
  if(.not. fileexists(bufferPath))then
    print("Create buffer folder: "+bufferPath)
    system("mkdir "+bufferPath)
  else
    i = 0
    do while (fileexists(bufferPath+"buffer"+i+".nc"))
      ListAppend(bufferFileList, bufferPath+"buffer"+i+".nc")
      f = addfile(bufferPath+"buffer"+i+".nc", "r")
      id := 0
      copy_VarAtts(f, id)
      ListAppend(bufferIdList, getRefer(id))
      i = i+1
    end do
    bufferCount = i
  print(bufferCount)
  end if
end

; undef("check_buffer")
; function check_buffer (id)
; local bufferName,isExist,fin,f_att,id_att,i,att,c
; begin
;   print(id)
;   bufferName = bufferPath+"buffer"+bufferCount+".nc"
;   isExist = isfilepresent(bufferName)
;   if(.not. isExist) 
;     print("file not exist")
;     return False 
;   end if
;   fin = addfile(bufferName, "r") 
;   f_att = getfileatts(fin)
;   id_att = getvaratts(id)
;   do i = 0, dimsizes(id_att)-1
;     att = id_att(i)
;     if(.not. isatt(fin,att) .or. dimsizes(fin@$att$) .ne. dimsizes(id@$att$)) return False end if
;     c := fin@$att$ .ne. id@$att$
;     if(isArray(c)) c := any(c) end if
;     if(c) return False end if
;   end do
;   return True
;   ; check = isatt(fin, "id") .and. (id .eq. fin@id)
;   ; return check
; end

undef("compareId")
function compareId(id0, id1)
local j,id0_att,id1_att,att,c
begin
  ; print("compare")
  ; print(id0)
  ; print(id1)
  id0_att = getvaratts(id0)
  id1_att = getvaratts(id1)
  do j = 0, dimsizes(id1_att)-1
    att = id1_att(j)
    if(.not. isatt(id0,att) .or. dimsizes(id0@$att$) .ne. dimsizes(id1@$att$)) 
      return False 
    end if
    c := id0@$att$ .ne. id1@$att$
    if(isArray(c)) c := any(c) end if
    if(c) return False end if
  end do
  return True
end
undef("check_buffer")
function check_buffer(id)
local bufferName,isExist,fin,f_att,id_att,i,j,att,c,bufferId,count,target
begin
  ; print(id)
  count = ListCount(bufferIdList)
  target = False
  do i = 0,count-1
    bufferId := bufferIdList[i]
    bufferId_att := getvaratts(bufferId)
    if(compareId(bufferId,id))then
      target = True
      break
    end if
  end do
  return target
end

undef("getBufferId")
function getBufferId (id)
local bufferName,isExist,fin,f_att,id_att,i,att,c,bufferId,count,target
begin
  ; print(id)
  count = ListCount(bufferIdList)
  target = -1
  do i = 0,count-1
    bufferId := bufferIdList[i]
    if(compareId(bufferId,id))then
      target = i
      break
    end if
  end do
  return target
  ; bufferName = bufferPath+"buffer"+bufferCount+".nc"
  ; isExist = isfilepresent(bufferName)
  ; if(.not. isExist) 
  ;   print("file not exist")
  ;   return False 
  ; end if
  ; fin = addfile(bufferName, "r") 
  ; f_att = getfileatts(fin)
  ; id_att = getvaratts(id)
  ; do i = 0, dimsizes(id_att)-1
  ;   att = id_att(i)
  ;   if(.not. isatt(fin,att) .or. dimsizes(fin@$att$) .ne. dimsizes(id@$att$)) return False end if
  ;   c := fin@$att$ .ne. id@$att$
  ;   if(isArray(c)) c := any(c) end if
  ;   if(c) return False end if
  ; end do
  ; return True
  ; check = isatt(fin, "id") .and. (id .eq. fin@id)
  ; return check
end

undef("check_buffers")
function check_buffers (id:list)
local count,i,bufferName,isExist,fin,f_att,tem_id,id_att,j,att
begin
  count = ListCount(id)
  do i = 0, count-1
    bufferName = bufferPath+"buffer"+(bufferCount+i)+".nc"
    isExist = isfilepresent(bufferName)
    if(.not. isExist) 
      print("file not exist")
      return False 
    end if
    fin = addfile(bufferName, "r") 
    f_att := getfileatts(fin)
    tem_id := id[i]
    id_att := getvaratts(tem_id)
    do j = 0, dimsizes(id_att)-1
      att = id_att(j)
      if(.not. isatt(fin,att) .or. dimsizes(fin@$att$) .ne. dimsizes(id[i]@$att$)) 
        print(1)
        return  False 
      end if
      c := fin@$att$ .ne. id[i]@$att$
      if(isArray(c)) c := any(c) end if
      if(c) 
        print(2)
        return False 
      end if
    end do
  end do
  return True
  ; check = isatt(fin, "id") .and. (id .eq. fin@id)
  ; return check
end

undef("read_buffer")
function read_buffer (id)
local bufferName,fin,buffer,bufferId,bufferName
begin
  bufferId = getBufferId(id)
  ; bufferName = bufferPath+"buffer"+bufferCount
  bufferName = bufferFileList[bufferId]
  print("readbuffer: "+bufferName)
  ; printc("read buffer"+bufferCount,"yellow")
  ; bufferCount = bufferCount+1
  ; system("rm -rf "+bufferName+".nc")
  fin = addfile(bufferName+".nc", "r")
  buffer = fin->buffer
  call_stream := NewList("fifo")
  return buffer
end

; undef("write_buffer")
; procedure write_buffer (buffer,id)
; local fout,bufferName
; begin
;   bufferName = bufferPath+"buffer"+bufferCount
;   printc("buffer"+bufferCount,"yellow")
;   bufferCount = bufferCount+1
;   system("rm -rf "+bufferName+".nc")
;   fout := addfile(bufferName+".nc", "c")
;   fileattdef(fout, id)
;   ; print(getfileatts(fout))
;   ; print(getvaratts(id))
;   fout->buffer = buffer
;   ; f = addfile(bufferName+".nc", "c")
;   call_stream := NewList("fifo")
; end

undef("write_buffer")
procedure write_buffer (buffer,id)
local fout,bufferName,tem_id
begin
  tem_id = id
  bufferName = bufferPath+"buffer"+bufferCount
  printc("buffer"+bufferCount,"yellow")
  bufferCount = bufferCount+1
  system("rm -rf "+bufferName+".nc")
  fout := addfile(bufferName+".nc", "c")
  fileattdef(fout, id)
  ; print(getfileatts(fout))
  ; print(getvaratts(id))
  fout->buffer = buffer
  ListAppend(bufferIdList, tem_id)
  ListAppend(bufferFileList, bufferName)
  ; f = addfile(bufferName+".nc", "c")
  call_stream := NewList("fifo")
end

undef("reset_buffer")
procedure reset_buffer ()
begin
  bufferCount = 0
  call_stream := NewList("fifo")
end

undef("id_append")
procedure id_append(id,var)
local listSize,tem,dim,i
begin
  if(typeof(var) .eq. "list")
    listSize = ListCount(var)
    do l = 0, listSize-1
      tem := var[l]
      dim = dimsizes(tem)
      do i = 0, dim-1
        id = id+var(i)
      end do
    end do
  else
    dim = dimsizes(var)
    do i = 0, dim-1
      id = id+var(i)
    end do
  end if
end