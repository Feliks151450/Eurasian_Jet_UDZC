undef("isNamedOrHex")
function isNamedOrHex(colors[*]:string)
local isNamed, isHex,nColor,isNamedOrHexColors,i,isSpecial
begin
  nColor = dimsizes(colors)
  isNamedOrHexColors = new(nColor, logical)
  do i = 0, nColor-1
    isNamed = is_valid_named_colors(colors(i))
    if(isNamed) 
      isNamedOrHexColors(i) = True 
      continue
    end if
    isSpecial = is_valid_special_colors(colors(i))
    if(isSpecial)
      isNamedOrHexColors(i) = True 
      continue
    end if
    isHex = .not. ismissing(str_match_ic_regex(colors(i), "^#[a-fA-F0-9]{6}"))
    isNamedOrHexColors(i) = isHex
  end do
  return all(isNamedOrHexColors)
end
undef("get_color_type")
function get_color_type(colors)
local dims_color, rank_color
begin
  dims_color = dimsizes(colors)
  rank_color = dimsizes(dims_color)

  if(typeof(colors).eq."string".and.all(is_valid_colormap_names(colors))) then
    return("colormap")
  elseif(typeof(colors).eq."string".and.all(is_valid_named_colors(colors))) then
    return("named")
  elseif(typeof(colors).eq."string".and.all(is_valid_special_colors(colors))) then
    return("special")
;
; This test is different, because we have to make sure all
; of the colors are either a named color or a special color.
; If you have one bad one in the bunch, then we can't 
; claim it is "mixed".
;
  elseif(typeof(colors).eq."string".and.(num(is_valid_named_colors(colors))+\
         num(is_valid_special_colors(colors))).eq.product(dims_color))
    return("mixed")
  elseif(typeof(colors) .eq. "string" .and. rank_color .eq. 1 .and. isNamedOrHex(colors))
    return("hex")
  elseif(dims_color(rank_color-1).eq.3.and.isnumeric(colors).and.\
         all(colors.ge.0.and.colors.le.1.0)) then
    return("rgb")
  elseif(dims_color(rank_color-1).eq.4.and.isnumeric(colors).and.\
         all(colors.ge.0.and.colors.le.1.0)) then
    return("rgba")
  elseif(isnumeric(colors).and.all(colors.ge.-1.and.colors.le.255)) then
    return("index")
  elseif(isnumeric(colors).and.all(colors.ge.(2^30).and.colors.le.((2^31)-1))) then
    return("absolute")
  else
    return("unknown")
  end if
end
undef("hex2rgba")
function hex2rgba(wks,colors[*]:string)
local tem,rgba,i,nColor
begin
  nColor = dimsizes(colors)
  rgba = new((/nColor,4/),float)
  rgba = 255
  do i = 0, nColor-1
    if(is_valid_named_colors(colors(i))) then
      rgba(i,:) = namedcolor2rgba(colors(i))
    elseif(is_valid_special_colors(colors(i))) then
      rgba(i,:) = specialcolor2rgba(wks,colors(i))
    else
      tem = str_split_by_length(str_split(colors(i), "#"), 2)
      rgba(i,:2) = stringtointeger("0x"+tem)
      rgba(i,:) = rgba(i,:)/255
    end if
  end do
  return rgba
end
undef("convert_color_to_rgba")
function convert_color_to_rgba(wks,colors)
local color_type, dims, rank, new_dims
begin
  color_type = get_color_type(colors)
  if(color_type.eq."rgba") then
    rgba_colors = colors
  elseif(color_type.eq."index") then
    rgba_colors = indexcolor2rgba(wks,colors)
  elseif(color_type.eq."absolute") then
    rgba_colors = color_index_to_rgba(colors)
  elseif(color_type.eq."colormap") then
    rgba_colors = read_colormap_files(colors)
  elseif(color_type.eq."named") then
    rgba_colors = namedcolor2rgba(colors)
  elseif(color_type.eq."special") then
    rgba_colors = specialcolor2rgba(wks,colors)
  elseif(color_type.eq."mixed") then
    rgba_colors = mixedcolor2rgba(wks,colors)
  elseif(color_type.eq."rgb") then
    rgba_colors = rgb2rgba(colors)
  elseif(color_type .eq. "hex") then
    rgba_colors = hex2rgba(wks,colors)
  else    ; color_type.eq."unknown"
    dims = dimsizes(colors)
    rank = dimsizes(dims)
    new_dims = new(rank+1,typeof(dims))
    new_dims(0:rank-1) = dims
    new_dims(rank)     = 4
    print("convert_color_to_rgba: Error: unknown color type.")
    print("   Returning all missing values.")
    return(new(new_dims,float))
  end if

  rank = dimsizes(dimsizes(rgba_colors))
  if(rank.eq.1.and.all(dimsizes(rgba_colors).eq.(/4/))) then
    return(reshape(rgba_colors,(/1,4/)))
  else
    return(rgba_colors)
  end if
end