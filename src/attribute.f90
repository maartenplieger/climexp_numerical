program attribute
!
!   do an empirical trend detection study by fitting a time series to a
!   Gaussian, Gumbell, GEV or GPD with the position parameter and/or scale parameter
!   linearly dependent on a covariate and studying the difference in return time
!   in the current climate and a previous climate.
!
    implicit none
    include 'param.inc'
    include 'getopts.inc'
    integer,parameter :: nresmax=100,mensmax=2000
    integer nperyear,nperyear1,mens1,mens,mmens1,mmens,iens,nresults
    integer i,yr,mo,n,off,nmetadata
    real results(3,nresmax)
    real,allocatable :: series(:,:,:),covariate(:,:,:)
    character :: seriesfile*1024,covariatefile*1024,distribution*6,assume*5,string*80,seriesids(0:mensmax)*30
    character :: var*40,units*80,lvar*120,svar*120,history*50000,metadata(2,100)*1000
    character :: var1*40,units1*80,lvar1*120,svar1*120,history1*50000,metadata1(2,100)*1000
    logical :: lprint,lfirst
    real scalingpower
    common /c_scalingpower/ scalingpower

    if ( command_argument_count().lt.8 ) then
        write(0,*) 'usage: attribute series covariate_series|none ', &
        & 'GEV|Gumbel|GPD|Gauss assume shift|scale', &
        & 'mon n [sel m] [ave N] [log|sqrt] ', &
        & 'begin2 past_climate_year end2 year_under_study', &
        & 'plot FAR_plot_file [dgt threshold%]'
        write(0,*) 'note that n and m are in months even if the series is daily.'
        write(0,*) 'N is always in the same units as the series.'
        write(0,*) 'the covariate series is averaged to the same time scale.'
        stop
    end if
!
!   initialisation
!
    call attribute_init(seriesfile,distribution,assume,off,nperyear,yrbeg,yrend,mensmax,lwrite)
    allocate(series(npermax,yrbeg:yrend,0:mensmax))
    if ( seriesfile == 'file' ) then
        ! set of stations
        call readsetseriesmeta(series,seriesids,npermax,yrbeg,yrend, &
            mensmax,nperyear,mens1,mens,var,units,lvar,svar, &
            history,metadata,lstandardunits,lwrite)
    else if ( seriesfile == 'gridpoints' ) then
        ! netcdf file with gridpoints
        call readgridpointsmeta(series,seriesids,npermax,yrbeg,yrend, &
            mensmax,nperyear,mens1,mens,nens1,nens2,var,units,lvar,svar, &
            history,metadata,lstandardunits,lwrite)
    else
        ! simple data
        !!!write(0,*) 'Reading time series...<p>'
        call readensseriesmeta(seriesfile,series,npermax,yrbeg,yrend, &
            mensmax,nperyear,mens1,mens,var,units,lvar,svar, &
            history,metadata,lstandardunits,lwrite)
        if ( mens.gt.mens1 ) then
            do i=mens1,mens
                write(seriesids(i),'(i3.3)') i
            enddo
        else
            seriesids(mens) = ' '
        end if
    end if
    
    call get_command_argument(2+off,covariatefile)
    allocate(covariate(npermax,yrbeg:yrend,0:mensmax))
    if ( covariatefile == 'none' ) then
        covariate = 0
        nperyear1 = 1
    else if ( index(covariatefile,'%%') == 0 .and. index(covariatefile,'++') == 0 ) then
        call readseriesmeta(covariatefile,covariate,npermax,yrbeg,yrend &
            ,nperyear1,var1,units1,lvar1,svar1,history1,metadata1,lstandardunits,lwrite)
        do iens=mens1,mens
            if ( iens /= 0 ) then
                covariate(:,:,iens) = covariate(:,:,0)
            end if
        end do
    else
        !!!write(0,*) 'Reading covariate series...<p>'
        call readensseriesmeta(covariatefile,covariate,npermax,yrbeg,yrend, &
            mensmax,nperyear1,mmens1,mmens,var1,units1,lvar1,svar1,history1,metadata1, &
            lstandardunits,lwrite)
        if ( mmens1 /= mens1 .or. mmens /= mens ) then
            write(0,*) 'attribute: error: number of ensemble members should be the same ', &
                'found covariate: ',mmens1,'-',mmens,', series ',mens1,'-',mens
            call exit(-1)
        end if
    end if
    
    call getopts(6+off,command_argument_count(),nperyear,yrbeg,yrend,.true.,mens1,mens)
    ! workaround, maybe debug more fully later
    mens1 = max(mens1,nens1)
    mens = min(mens,nens2)
!
!   merge metadata
!
    if (covariatefile /= 'none' ) then
        do i=1,100
            if ( metadata(1,i) == ' ' ) exit
        end do
       nmetadata = i - 1
        call merge_metadata(metadata,nmetadata,metadata1,' ',history1,'covariate_')
        call add_varnames_metadata(var1,lvar1,svar1,metadata1,'covariate')
    end if
!
!   process data
!
    !!!write(0,*) 'Transforming series...<p>'
    if ( biasmul /= 1 .or. biasadd /= 0 ) then
        write(0,*) 'Applying bias correction of scale ',biasmul,' and offset ',biasadd
        print '(a,g20.4,a,g20.4,a)','# Applying bias correction of scale ',biasmul,' and offset ',biasadd
        do iens=mens1,mens
            call scaleseries(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend,biasmul,1,biasadd,1,0)
        end do
    end if
    if ( ldetrend ) then
        do iens=mens1,mens
            call detrend(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend,yr1,yr2,m1,m2,lsel)
            lfirst = .true.
            if ( lfirst .and. covariatefile /= 'none' ) then
                lfirst = .false.
                call detrend(covariate(1,yrbeg,iens),npermax,nperyear1,yrbeg,yrend,yr1,yr2,m1,m2,lsel)
            end if
        end do
    end if
    if ( anom ) then
        if ( assume == 'scale' ) then
            write(0,*) 'error: it makes no sense to use "scale" on anomalies'
            write(*,*) 'error: it makes no sense to use "scale" on anomalies'
            call exit(-1)
        end if
        do iens=mens1,mens
            call anomal(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend,yr1,yr2)
        end do
    end if
    if ( lsum.gt.1 ) then
        do iens=mens1,mens
            call sumit(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend,lsum,oper)
        end do
    endif
    scalingpower = 1
    if ( logscale ) then
        print '(a)','# taking logarithm'
        do iens=mens1,mens
            call takelog(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend)
        end do
        if ( xyear.lt.1e33 ) xyear = log(xyear)
        scalingpower = 0
    endif
    if ( sqrtscale ) then
        print '(a)','# taking sqrt'
        do iens=mens1,mens
            call takesqrt(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend)
        end do
        if ( xyear.lt.1e33 ) xyear = sqrt(xyear)
        scalingpower = scalingpower*0.5
    endif
    if ( squarescale ) then
        print '(a)','# taking square'
        do iens=mens1,mens
            call takesquare(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend)
        end do
        if ( xyear.lt.1e33 ) xyear = xyear**2
        scalingpower = scalingpower*2
    endif
    if ( cubescale ) then
        print '(a)','# taking square'
        do iens=mens1,mens
            call takecube(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend)
        end do
        if ( xyear.lt.1e33 ) xyear = xyear**3
        scalingpower = scalingpower*3
    endif
    if ( twothirdscale ) then
        print '(a)','# taking power two-third'
        do iens=mens1,mens
            call taketwothird(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend)
        end do
        if ( xyear.lt.1e33 .and. xyear.ge.0 ) xyear = xyear**(2/3.)
        scalingpower = scalingpower*2./3.
    endif
    if ( lchangesign ) then
        do iens=mens1,mens
            call changesign(series(1,yrbeg,iens),npermax,nperyear,yrbeg,yrend)
        end do
        if ( xyear.lt.1e30 ) then
            xyear = -xyear
        end if
    endif

    lprint = .true.
    if ( lwrite ) print *,'attribute: calling attribute_dist'
    call attribute_dist(series,nperyear,covariate,nperyear1,npermax,yrbeg,yrend, &
        mens1,mens,assume,distribution,seriesids,results,nresmax,nresults,lprint, &
        var,units,lvar,svar,history,metadata)

end program attribute

