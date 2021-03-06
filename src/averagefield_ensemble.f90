program average_field_ensemble

!   Compute the ensemble average of a field.

    implicit none
    include 'params.h'
    include 'netcdf.inc'
    include 'getopts.inc'
    integer,parameter :: recfa4=4
    integer,parameter :: nvarmax=4,nyrmax=79,ntmax=nyrmax*npermax
    integer :: i,j,k,iens,n,mo,yr,nx,ny,nz,nt,nperyear,firstyr,firstmo &
        ,lastyr,nvars,ivars(2,nvarmax),jvars(6,nvarmax),ncid,ncid2 &
        ,endian,status,iarg,mens1,mens,irec,fyr,it,ivar &
        ,itimeaxis(ntmax),ntvarid
    logical :: lexist,tdefined(ntmax)
    real :: xx(nxmax),yy(nymax),zz(nzmax),undef,s,s2,xmin,xmax
    real,allocatable :: field(:,:,:,:,:,:),result(:,:,:,:,:,:)
    character :: title*255,vars(1)*20,lvars(1)*80,units(1)*80, &
        ovars(nvarmax)*20,olvars(nvarmax)*80,osvars(nvarmax)*80, &
        ounits(nvarmax)*60,yesno*1,kind*3
    character :: infile*1023,datfile*1023,line*255,dir*255,outfile*1023
    character :: lz(3)*20,svars(1)*100,ltime*120,history*50000, &
        cell_methods(100)*100,metadata(2,100)*2000

    lwrite = .false. 
    if ( command_argument_count() < 3 ) then
        print *,'usage: average_field_ensemble field.[ctl|nc] '// &
            'mean|sd|min|max|all [ens n1 n2] outfield.[ctl|nc]'
        call exit(-1)
    endif
    call get_command_argument(2,kind)
    call get_command_argument(1,infile)
    if ( index(infile,'%') > 0 .or. index(infile,'++') > 0 ) then
        ensemble = .true. 
        call filloutens(infile,0)
        inquire(file=infile,exist=lexist)
        if ( .not. lexist ) then
            mens1 = 1
            call get_command_argument(1,infile)
            call filloutens(infile,1)
        else
            mens1 = 0
        endif
    else
        ensemble = .false. 
        mens1 = 0
        mens = 0
    endif
    if ( lwrite ) print *,'average_field_ensemble: nf_opening file ',trim(infile)
    status = nf_open(infile,nf_nowrite,ncid)
    if ( status /= nf_noerr ) then
        call parsectl(infile,datfile,nxmax,nx,xx,nymax,ny,yy,nzmax,nz &
            ,zz,nt,nperyear,firstyr,firstmo,undef,endian,title,1 &
            ,nvars,vars,ivars,lvars,units)
        ncid = -1
        if ( ensemble ) then
            do mens=1,nensmax
                call get_command_argument(1,line)
                call filloutens(line,mens)
                inquire(file=line,exist=lexist)
                if ( .not. lexist ) go to 100
            enddo
        100 continue
            mens = mens - 1
            write(0,*) 'located ',mens-mens1+1,' ensemble members<br>'
        endif
    else
        if ( lwrite ) print *,'calling parsenc on ',trim(infile)
        call ensparsenc(infile,ncid,nxmax,nx,xx,nymax,ny,yy,nzmax, &
            nz,zz,lz,nt,nperyear,firstyr,firstmo,ltime,tdefined,ntmax, &
            nens1,nens2,undef,title,history,1,nvars,vars,jvars,lvars,svars, &
            units,cell_methods,metadata)
        mens = nens2
        mens1 = nens1
        write(0,*) 'located ',nens2-nens1+1,' ensemble members<br>'
    endif
    call getlastyr(firstyr,firstmo,nt,nperyear,lastyr)
    if ( lwrite ) then
        print *,'allocating field(',nx,ny,nz,nperyear,firstyr,lastyr,mens,')'
    end if
    allocate(field(nx,ny,nz,nperyear,firstyr:lastyr,0:mens))
    allocate(result(nx,ny,nz,nperyear,firstyr:lastyr,4))
!   process arguments
    call getopts(3,command_argument_count()-1,nperyear,yrbeg,yrend,.true.,mens1,mens)
    yr1 = max(yr1,firstyr)
    yr2 = min(yr2,lastyr)
    call keepalive(0,0)
    if ( ncid == -1 ) then
        do iens=nens1,nens2
            call get_command_argument(1,infile)
            if ( ensemble ) then
                if ( iens == nens1 ) then
                    write(0,*) 'Using ensemble members ',nens1,' to ',nens2,'<p>'
                endif
                call filloutens(infile,iens)
            endif
            call parsectl(infile,datfile,nxmax,nx,xx,nymax,ny,yy &
                ,nzmax,nz,zz,nt,nperyear,fyr,firstmo,undef &
                ,endian,title,1,nvars,vars,ivars,lvars,units)
            call zreaddatfile(datfile,field(1,1,1,1,firstyr,iens), &
                nx,ny,nz,nx,ny,nz,nperyear,firstyr,lastyr, &
                fyr,firstmo,nt,undef,endian,lwrite, &
                yr1,yr2,1,1)
        enddo
    else
        do iens=nens1,nens2
            call keepalive2('Reading ensemble member ',iens-nens1+1,nens2-nens1+1,.true.)
            call get_command_argument(1,infile)
            if ( ensemble ) then
                if ( iens == nens1 ) then
                    write(0,*) 'Using ensemble members ',nens1,' to ',nens2,'<p>'
                endif
                call filloutens(infile,iens)
            endif
            status = nf_open(infile,nf_nowrite,ncid)
            call parsenc(infile,ncid,nxmax,nx,xx,nymax,ny,yy &
                ,nzmax,nz,zz,nt,nperyear,fyr,firstmo,undef &
                ,title,1,nvars,vars,jvars,lvars,units)
            call zreadncfile(ncid,field(1,1,1,1,firstyr,iens), &
                nx,ny,nz,nx,ny,nz,nperyear,firstyr,lastyr, &
                fyr,firstmo,nt,undef,lwrite,yr1,yr2,jvars)
            ivars(1,1) = nz
            ivars(2,1) = 99
        enddo
    endif

!   open output file

    call get_command_argument(command_argument_count(),outfile)
    inquire(file=outfile,exist=lexist)
    if ( lexist ) then
        print *,'output file ',outfile(1:index(outfile,' ')-1), &
            ' already exists, overwrite? [y/n]'
        read(*,'(a)') yesno
        if (  yesno /= 'y' .and. yesno /= 'Y' .and. &
        yesno /= 'j' .and. yesno /= 'J' ) then
            call exit(-1)
        endif
        open(2,file=outfile)
        close(2,status='delete')
    endif

!   compute ensemble mean

    do yr=yr1,yr2
        call keepalive1('Computing average year',yr-yr1+1,yr2-yr1+1)
        do mo=1,nperyear
            do k=1,nz
                do j=1,ny
                    do i=1,nx
                        s = 0
                        n = 0
                        xmin = +3e33
                        xmax = -3e33
                        do iens=nens1,nens2
                            if ( field(i,j,k,mo,yr,iens) < 1e33 ) then
                                n = n + 1
                                s = s + field(i,j,k,mo,yr,iens)
                                xmin = min(xmin,field(i,j,k,mo,yr,iens))
                                xmax = max(xmax,field(i,j,k,mo,yr,iens))
                            end if
                        end do
                        if ( n > 0 ) then
                            result(i,j,k,mo,yr,1) = s/n
                            result(i,j,k,mo,yr,3) = xmin
                            result(i,j,k,mo,yr,4) = xmax
                            s = 0
                            n = 0
                            do iens=nens1,nens2
                                if ( field(i,j,k,mo,yr,iens) < 1e33 ) then
                                    if (abs(field(i,j,k,mo,yr,iens)) > 1e15 ) then
                                        write(0,*) 'field(',i,j,k,mo,yr,iens,') = ', &
                                            field(i,j,k,mo,yr,iens)
                                    else
                                        n = n + 1
                                        s = s + (field(i,j,k,mo,yr,iens) - result(i,j,k,mo,yr,1))**2
                                    end if
                                end if
                            end do
                            if ( n > 1 ) then
                                result(i,j,k,mo,yr,2) = sqrt(s/(n-1))
                            else
                                result(i,j,k,mo,yr,2) = 3e33
                            end if
                        else
                            result(i,j,k,mo,yr,1:4) = 3e33
                        end if
                    end do
                end do
            end do
        end do
    end  do

!   write output

    title = 'ensemble properties of '//title
    i = index(outfile,'.ctl')
    if ( i /= 0 ) then
        datfile = outfile(1:i-1)//'.grd'
        open(1,file=datfile,form='unformatted',access='direct',recl=recfa4*nx*ny)
        irec = 0
    end if
    undef = 3e33
    nt = nperyear*(yr2-yr1+1)
    nvars = 0
    if ( kind == 'mea' .or. kind == 'ave' .or. kind == 'all' ) then
        nvars = nvars + 1
        if ( kind == 'all' ) then
            ovars(nvars) = 'mean_'//vars(1)
        else
            ovars(nvars) = vars(1)
        end if
        olvars(nvars) = 'ensemble mean of '//lvars(1)
        ounits(nvars) = units(1)
    endif
    if ( kind == 'sd' .or. kind == 's.d' .or. kind == 'all' ) then
        nvars = nvars + 1
        if ( kind == 'all' ) then
            ovars(nvars) = 'sd_'//vars(1)
        else
            ovars(nvars) = vars(1)
        end if
        olvars(nvars) = 'ensemble standard deviation of '//lvars(1)
        ounits(nvars) = units(1)
    endif
    if ( kind == 'min' .or. kind == 'all' ) then
        nvars = nvars + 1
        if ( kind == 'all' ) then
            ovars(nvars) = 'min_'//lvars(1)
        else
            ovars(nvars) = vars(1)
        end if
        olvars(nvars) = 'ensemble minimum of '//lvars(1)
        ounits(nvars) = units(1)
    endif
    if ( kind == 'max' .or. kind == 'all' ) then
        nvars = nvars + 1
        if ( kind == 'all' ) then
            ovars(nvars) = 'max_'//lvars(1)
        else
            ovars(nvars) = vars(1)
        end if
        olvars(nvars) = 'ensemble maximum of '//lvars(1)
        ounits(nvars) = units(1)
    endif
    osvars(1:4) = svars(1)
    ivars(1,2:4) = ivars(1,1)
    ivars(2,2:4) = ivars(2,1)
    if ( index(outfile,'.ctl') /= 0 ) then
        call writectl(outfile,datfile,nx,xx,ny,yy,nz,zz, &
            nt,nperyear,yr1,1,undef,title,nvars,ovars,ivars &
            ,olvars,ounits)
    else
        call enswritenc(outfile,ncid,ntvarid,itimeaxis,ntmax,nx,xx, &
            ny,yy,nz,zz,lz,nt,nperyear,yr1,1,ltime,undef,title, &
            history,nvars,ovars,ivars,olvars,osvars,ounits,cell_methods, &
            metadata,0,0)
    end if
    it = 0
    do yr=yr1,yr2
        call keepalive1('Writing output year',yr-yr1+1,yr2-yr1+1)
        do mo=1,nperyear
            if ( nperyear == 366 .and. mo == 31+29 ) cycle
            it = it + 1
            ivar = 0
            if ( kind == 'mea' .or. kind == 'ave' .or. kind == 'all' ) then
                ivar = ivar + 1
                if ( index(outfile,'.ctl') /= 0 ) then
                    irec = irec + 1
                    write(1,rec=irec) (((result(i,j,k,mo,yr,1),i=1,nx),j=1,ny),k=1,nz)
                else
                    call writencslice(ncid,0,0,0,ivars(1,ivar), &
                    result(1,1,1,mo,yr,1),nx,ny,nz,nx,ny,nz, &
                    it,1)
                end if
            endif
            if ( kind == 'sd' .or. kind == 's.d' .or. kind == 'all' ) then
                ivar = ivar + 1
                if ( index(outfile,'.ctl') /= 0 ) then
                    irec = irec + 1
                    write(1,rec=irec) (((result(i,j,k,mo,yr,2), &
                        i=1,nx),j=1,ny),k=1,nz)
                else
                    call writencslice(ncid,0,0,0,ivars(1,ivar), &
                        result(1,1,1,mo,yr,2),nx,ny,nz,nx,ny,nz,irec,1)
                end if
            endif
            if ( kind == 'min' .or. kind == 'all' ) then
                ivar = ivar + 1
                if ( index(outfile,'.ctl') /= 0 ) then
                    irec = irec + 1
                    write(1,rec=irec) (((result(i,j,k,mo,yr,3), &
                        i=1,nx),j=1,ny),k=1,nz)
                else
                    call writencslice(ncid,0,0,0,ivars(1,ivar), &
                        result(1,1,1,mo,yr,3),nx,ny,nz,nx,ny,nz,irec,1)
                end if
            endif
            if ( kind == 'max' .or. kind == 'all' ) then
                ivar = ivar + 1
                if ( index(outfile,'.ctl') /= 0 ) then
                    irec = irec + 1
                    write(1,rec=irec) (((result(i,j,k,mo,yr,4), &
                        i=1,nx),j=1,ny),k=1,nz)
                else
                    call writencslice(ncid,0,0,0,ivars(1,ivar), &
                        result(1,1,1,mo,yr,4),nx,ny,nz,nx,ny,nz,irec,1)
                end if
            endif
        enddo
    enddo
    if ( index(outfile,'.ctl') /= 0 ) then
        close(1)
    else
        status = nf_close(ncid)
    end if
end program average_field_ensemble
