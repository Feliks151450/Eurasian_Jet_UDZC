undef("read_cam_clim")
function read_cam_clim(type)
local id,ctl,exp0,names,months,months,U0,U0_re,U0_JA,U_clim
begin
  call_read_cam_clim = "read_cam_clim"
  ListAppend(call_stream, call_read_cam_clim)
  printc("start: read_cam_clim","green")
  id = type
    id@type = type
    id@call = call_read_cam_clim
  if(call_stream[0] .eq. call_read_cam_clim .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
    return(read_buffer)
  end if
    ctl = addfile(localpath(2)+"CAM/F2000.CAM.nc","r")
    exp0 = addfile(localpath(2)+"CAM/LLF_IcelandSST.CAM.1981_2000.nc","r")
    ; exp1 = addfile(localpath(2)+"LLF/IcelandSST2.CAM.nc","r")
    ; ctl = addfile(localpath(2)+"LLF/LLF_CTL.CAM.nc","r")
    ; exp0 = addfile(localpath(2)+"LLF/LLF_ICELANDSST.CAM.nc","r")
    names = (/"U","V","Z","slp"/)
    months   = (/"J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D"/)
    month    = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
    U0 = ctl->$names(type)$(:,:,{0:90},:)
    ; U0 = exp0->$names(type)$(:,:,0:90,:)
    dims = dimsizes(U0)
    U0_re = reshape(U0,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
    ; U1_re = reshape(U1,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
    U0_re!0 = "year"
    U0_re&year = ispan(1,30,1)
    U0_re!1 = "mon"
    U0_re&mon = ispan(2,13,1)
    copy_VarCoords(U0(0,:,:,:),U0_re(0,0,:,:,:))
    ; copy_VarCoords(U0_re,U1_re)
    if(dimsizes(type@month) .eq. 1)
        U0_JA = U0_re({type@start:},{type@month},{type@level},:,:)
        ; U1_JA = U1_re({type@start:},{type@month},:,:,:)
    else
        U0_JA = dim_avg_n_Wrap(U0_re({type@start:},{type@month},{type@level},:,:),1)
        ; U1_JA = dim_avg_n_Wrap(U1_re({type@start:},{type@month},:,:,:),1)
    end if
    ; U0_JA_avg = dim_avg_n_Wrap(U0_JA(:,{type@level},:,:),0) 
    ; printVarSummary(U0_JA_avg)
    ; U0_JA_avg@Scale = 5
    U_clim = dim_avg_n_Wrap(U0_JA,0)
    U_clim@name = names(type)+type@level

    ; U200_dif = U1_JA(:,{type@level},:,:)-U0_JA(:,{type@level},:,:)
    ; copy_VarCoords(U0_JA(:,{type@level},:,:),U200_dif)
    ; U200_dif_avg = dim_avg_n_Wrap(U200_dif,0)
    ; U200_dif_avg@name = names(type)+type@level
    if(dimsizes(type@month) .eq. 1 ) 
        U_clim@mon_name = month(type@month-1)
        ; copy_VarCoords(var,var0)
    else
        U_clim@mon_name = ""
        do i = 0,dimsizes(type@month)-1,1
          U_clim@mon_name = U_clim@mon_name+months(type@month(i)-1)
        end do
    end if
    if((call_stream[0] .eq. call_read_cam_clim) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(U_clim,id)
    end if
    return(U_clim)
end

undef("read_cam_dif")
function read_cam_dif(tp)
local type,ctl,exp0,names,months,month,U0,time,U1,dims,U0_re,U200_dif
begin
  call_read_cam_dif = "read_cam_dif"
  ListAppend(call_stream, call_read_cam_dif)
  printc("start: read_cam_dif","green")
  type = tp
  if( .not. isatt(type, "end"))then
    type@end = 30
  end if
  id = type
    id@type = type
    id@call = call_read_cam_dif
  if(call_stream[0] .eq. call_read_cam_dif .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
    return(read_buffer)
  end if
    ctl = addfile(localpath(2)+"CAM/F2000.CAM.nc","r")
    exp0 = addfile(localpath(2)+"CAM/LLF_IcelandSST.CAM.1981_2000.nc","r")
    ; exp1 = addfile(readpath(0)+"LLF/IcelandSST2.CAM.nc","r")
    ; ctl = addfile(readpath(0)+"LLF/LLF_CTL.CAM.nc","r")
    ; exp0 = addfile(readpath(0)+"LLF/LLF_ICELANDSST.CAM.nc","r")
    names = (/"U","V","Z","slp"/)
    months   = (/"J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D"/)
    month    = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
    U0 = ctl->$names(type)$(:,:,{0:90},:)
    time = cd_calendar(U0&time, -1)
    ; print(time)
    U1 = exp0->$names(type)$(:,:,{0:90},:)
    dims = dimsizes(U0)
    U0_re = reshape(U0,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
    U1_re = reshape(U1,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
    U0_re!0 = "year"
    U0_re&year = ispan(1,30,1)
    U0_re!1 = "mon"
    U0_re&mon = ispan(2,13,1)
    copy_VarCoords(U0(0,:,:,:),U0_re(0,0,:,:,:))
    copy_VarCoords(U0_re,U1_re)
    if(dimsizes(type@month) .eq. 1)
        U0_JA = U0_re({5:},{type@month},:,:,:)
        U1_JA = U1_re({type@start:type@end},{type@month},:,:,:)
    else
        U0_JA = dim_avg_n_Wrap(U0_re({5:},{type@month},:,:,:),1)
        U1_JA = dim_avg_n_Wrap(U1_re({type@start:type@end},{type@month},:,:,:),1)
    end if
    ; U0_JA_avg = dim_avg_n_Wrap(U0_JA(:,{type@level},:,:),0) 
    ; printVarSummary(U0_JA_avg)
    ; U0_JA_avg@Scale = 5
    U0_JA_clim = dim_avg_n_Wrap(U0_JA(:,{type@level},:,:), 0)
    U200_JA = U1_JA(:,{type@level},:,:)
    U0_JA_clim_conform = conform_dims(dimsizes(U200_JA), U0_JA_clim, (/1,2/))
    U200_JA_anom = U200_JA-U0_JA_clim_conform
    U200_dif = dim_avg_n_Wrap(U200_JA_anom, 0)
    copy_VarCoords(U0_JA_clim, U200_dif)
    U200_stddev = dim_stddev_n_Wrap(U200_JA_anom, 0)
    U200_t = U200_dif/U200_stddev*sqrt(type@end-type@start+1)
    copy_VarCoords(U0_JA_clim, U200_t)


    ; U200_dif = U1_JA(:,{type@level},:,:)-U0_JA(:,{type@level},:,:)
    ; copy_VarCoords(U0_JA(:,{type@level},:,:),U200_dif)
    ; U200_dif_avg = dim_avg_n_Wrap(U200_dif,0)
    U200_dif@name = names(type)+type@level
    if(dimsizes(type@month) .eq. 1 ) 
        U200_dif@mon_name = month(type@month-1)
        ; copy_VarCoords(var,var0)
    else
        U200_dif@mon_name = ""
        do i = 0,dimsizes(type@month)-1,1
          U200_dif@mon_name = U200_dif@mon_name+months(type@month(i)-1)
        end do
    end if
    if((call_stream[0] .eq. call_read_cam_dif) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(U200_dif,id)
    end if
    return[/U200_dif,U200_t/]
end

undef("read_cam_stddev")
function read_cam_stddev(tp)
local id,ctl,exp0,names,months,month,U1,U1_re,U200_stddev,type
begin
  call_read_cam_stddev = "read_cam_stddev"
  ListAppend(call_stream, call_read_cam_stddev)
  printc("start: read_cam_stddev","green")
  type = tp
  if( .not. isatt(type, "end"))then
    type@end = 30
  end if
  id = type
    id@type = type
    id@call = call_read_cam_stddev
  if(call_stream[0] .eq. call_read_cam_stddev .and. is_element(bufferMode,(/"read","smart"/)) .and. check_buffer(id))
    return(read_buffer)
  end if
    ctl = addfile(localpath(2)+"CAM/F2000.CAM.nc","r")
    exp0 = addfile(localpath(2)+"CAM/LLF_IcelandSST.CAM.1981_2000.nc","r")
    ; exp1 = addfile(readpath(0)+"LLF/IcelandSST2.CAM.nc","r")
    ; ctl = addfile(readpath(0)+"LLF/LLF_CTL.CAM.nc","r")
    ; exp0 = addfile(readpath(0)+"LLF/LLF_ICELANDSST.CAM.nc","r")
    names = (/"U","V","Z","slp"/)
    months   = (/"J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D"/)
    month    = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
    U0 = ctl->$names(type)$(:,:,0:90,:)
    U1 = exp0->$names(type)$(:,:,{0:90},:)
    ; printVarSummary(U1)
    dims = dimsizes(U1)
    U0_re = reshape(U0,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
    U1_re = reshape(U1,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
    U1_re!0 = "year"
    U1_re&year = ispan(1,30,1)
    U1_re!1 = "mon"
    U1_re&mon = ispan(2,13,1)
    copy_VarCoords(U1(0,:,:,:),U1_re(0,0,:,:,:))
    if(dimsizes(type@month) .eq. 1)
        U1_JA = U1_re({type@start:},{type@month},{type@level},:,:)
    else
        U1_JA = dim_avg_n_Wrap(U1_re({type@start:},{type@month},{type@level},:,:),1)
    end if

    ; U0_JA_avg = dim_avg_n_Wrap(U0_JA(:,{type@level},:,:),0) 
    ; printVarSummary(U0_JA_avg)
    ; U0_JA_avg@Scale = 5
    U200_stddev = dim_stddev_n_Wrap(U1_JA,0)
    copy_VarCoords(U1_JA(0,:,:),U200_stddev)
    if(dimsizes(type@month) .eq. 1 ) 
        U200_stddev@mon_name = month(type@month-1)
        ; copy_VarCoords(var,var0)
    else
        U200_stddev@mon_name = ""
        do i = 0,dimsizes(type@month)-1,1
          U200_stddev@mon_name = U200_stddev@mon_name+months(type@month(i)-1)
        end do
    end if
    if((call_stream[0] .eq. call_read_cam_stddev) .and. is_element(bufferMode,(/"write","smart"/)))
      write_buffer(U200_stddev,id)
    end if
    return(U200_stddev)
end

undef("read_cam_jet_axis")
function read_cam_jet_axis(type)
local ctl,names,months,month,U1,U1_re,U1_JA,U1_clim,ind_lon,lat
begin
  ctl = addfile(localpath(2)+"CAM/F2000.CAM.nc","r")
  names = (/"U","V","Z","slp"/)
  months   = (/"J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D","J","F","M","A","M","J","J","A","S","O","N","D"/)
  month    = (/"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)
  ; U0 = ctl->$names(type)$(:,:,0:90,:)
  U1 = ctl->U(:,:,{0:90},:)
  dims = dimsizes(U1)
  U1_re = reshape(U1,(/dims(0)/12,12,dims(1),dims(2),dims(3)/))
  U1_re!0 = "year"
  U1_re&year = ispan(1,30,1)
  U1_re!1 = "mon"
  ; U1_re&mon = ispan(1,12,1)
  U1_re&mon = ispan(2,13,1)
  copy_VarCoords(U1(0,:,:,:),U1_re(0,0,:,:,:))
  if(dimsizes(type@month) .eq. 1)
      U1_JA = U1_re({type@start:},{type@month},{type@level},:,:)
  else
      U1_JA = dim_avg_n_Wrap(U1_re({type@start:},{type@month},{type@level},:,:),1)
  end if
  U1_clim = dim_avg_n_Wrap(U1_JA, 0)
  lat = getJetAxis(U1_clim)
  return lat
end