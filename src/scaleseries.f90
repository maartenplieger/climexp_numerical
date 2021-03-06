program scaletimeseries

!   scale a time series and optionally apply an offset

    implicit none
    include 'param.inc'
    integer :: i,j,nperyear,ndpm,nfactor,noffset
    real :: data(npermax,yrbeg:yrend),factor(12),offset(12)
    character :: string*1024,var*40,units*40,lvar*120,svar*120,metadata(2,100)*2000, &
        history*50000,title*500
    logical :: lwrite

    lwrite = .false. 
    if ( command_argument_count() < 2 ) then
        print *,'usage: scaleseries factor[:offset] file [ndpm]'
        print *,'       factor and offset can be 12 values as "val1;val2;val3;...;val12"'
        call exit(-1)
    endif
    call get_command_argument(1,string)
    i = index(string,':')
    if ( i == 0 ) then
        call read12values(string,factor,nfactor,';')
        noffset = 1
        offset = 0
    else
        call read12values(string(:i-1),factor,nfactor,';')
        call read12values(string(i+1:),offset,noffset,';')
    end if
    if ( command_argument_count() > 2 ) then
        call get_command_argument(3,string)
        read(string,*,err=10) ndpm
        goto 20
    10  continue
        ndpm = 0
    20  continue
    else
        ndpm = 0
    endif
    call get_command_argument(2,string)
    call readseriesmeta(string,data,npermax,yrbeg,yrend,nperyear,var,units,lvar,svar,history,metadata, &
        .false.,lwrite)
    if ( ndpm /= 0 .and. nperyear /= 12 ) then
        write(0,*) 'scaleseries: error: can only scale by dpm if nperyear = 12, not ',nperyear
        write(*,*) 'scaleseries: error: can only scale by dpm if nperyear = 12, not ',nperyear
        call exit(-1)
    endif
    title = ' '
    call printvar(6,var,units,lvar)
    call copyheadermeta(string,6,title,history,metadata)
    write(6,'(a,12g16.6)') '# scale_factor :: ',(factor(i),i=1,nfactor)
    if ( ndpm == 1 ) then
        write(6,'(a)')'# scale_factor_dpm :: multiplied by the number of days in a month'
    elseif ( ndpm == 2 ) then
        write(6,'(a)') '# scale_factor_dpm :: multiplied by the number of days in a month squared'
    elseif ( ndpm == -1 ) then
        write(6,'(a)')'# scale_factor_dpm :: divided by the number of days in a month'
    elseif ( ndpm == -2 ) then
        write(6,'(a)') '# scale_factor_dpm :: divided by the number of days in a month squared'
    elseif ( ndpm /= 0 ) then
        write(6,'(a,i3)') '# scale_factor_dpm :: multiplied by dpm**',ndpm
    endif
    if ( any(offset(1:noffset) /= 0) ) then
        write(6,'(a,12g16.6)') '# added_offset :: ',(offset(i),i=1,noffset)
    end if
    call scaleseries(data,npermax,nperyear,yrbeg,yrend,factor,nfactor,offset,noffset,ndpm)
    call printdatfile(6,data,npermax,nperyear,yrbeg,yrend)
end program scaletimeseries

subroutine read12values(string,val,nval,sep)
!
!   read 1 or more values from string seperated bij sep
!
    implicit none
    integer :: nval
    real :: val(12)
    character :: string*(*),sep*1
    integer :: i,iold
    
    val = 3e33
    i = index(string,sep)
    if ( i == 0 ) then
        nval = 1
        read(string,*) val(1)
    else
        nval = 0
        iold = 0
        do while ( i > iold )
            nval = nval + 1
            read(string(iold+1:i-1),*) val(nval)
            iold = i
            i = iold + index(string(i+1:),sep)
        end do
        nval = nval + 1
        read(string(i+1:),*) val(nval)
    end if
    !!!print *,'read12values: nval,val = ',nval,(val(i),i=1,nval)
end subroutine

