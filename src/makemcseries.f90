subroutine makemcseries(data,indx,npermax,yrbeg &
    ,yrend,nensmax,indxmx,nperyear,k,lag,j1,j2,imens &
    ,adata,sxx,aindx,syy,sxy,alpha,n)

!   make a (set of) timeseries in data or indx that has the same
!   fit and sd as the original one with white noise otherwise
!   13-jun-2005 added autocorrelations alpha
!   (1: month-to-month, day-to-day, ..., 2:year-to-year)

    implicit none
    include 'getopts.inc'
    integer :: npermax,yrbeg,yrend,nensmax,indxmx,nperyear,k,lag,j1,j2 &
        ,imens(0:indxmx),n
    real :: data(npermax,yrbeg:yrend,0:nensmax), &
        indx(npermax,yrbeg:yrend,0:nensmax,indxmx), &
        adata,sxx,aindx,syy,sxy,alpha
    integer :: iran,yr,i,jj,j,m,ii,iiens,iens,jens
    real :: a(2),sd,eta,eta0
    logical,save :: lfirst=.false.
    real,external :: gasdev

    if ( lrandom ) then
        if ( sxx == 0 ) then
            if ( lwrite ) then
                write(*,*) 'makemcseries: s.d. of series1 is 0'
            end if
            indx = 3e33
            return
        endif
        a(1) = sxy/sxx
        a(2) = aindx - a(1)*adata
        sd   = sqrt(max(0.,syy - sxy**2/sxx)/(n-1))
    else
        if ( syy == 0 ) then
            if ( lwrite ) then
                write(*,*) 'makemcseries: s.d. of series2 is 0'
            end if
            data = 3e33
            return
        endif

        a(1) = sxy/syy
        a(2) = adata - a(1)*aindx
        sd   = sqrt(max(0.,sxx - sxy**2/syy)/(n-1))
    endif
    if ( lwrite .or. lfirst ) then
        lfirst = .false. 
        print *,'makemcseries: a,b,sd,t = ',a,sd,sxy/sqrt(sxx*syy),lrandom,gasdev(iran)
    endif
    eta0 = 3e33
    do yr=yr1-1,yr2
        do jj=j1,j2
            if ( fix2 ) then
                j = jj+lag
            else
                j = jj
            endif
            call normon(j,yr,i,nperyear)
            if ( i < yr1 .or. i > yr2 ) go to 710
            m = j-lag
            call normon(m,i,ii,nperyear)
            if ( ii < yr1 .or. ii > yr2 ) go to 710
            do iiens=nens1,nens2
                if ( imens(0) > 0 ) then
                    iens = iiens
                else
                    iens = 0
                endif
                if ( imens(k) > 0 ) then
                    jens = iiens
                else
                    jens = 0
                endif
                eta = gasdev(iran)
                if ( noisetype == 1 ) then
                    if ( alpha /= 0 .and. eta0 < 1e33 ) then
                        eta = (1-alpha**2)*eta + alpha*eta0
                    endif
                    eta0 = eta
                endif
                if ( lrandom ) then
                    if ( data(j,i,iens) < 1e33 .and. indx(m,ii,jens,k) < 1e33 ) then
                        indx(m,ii,iiens,k) = a(2) + a(1)*data(j,i,iens) + sd*eta
                    else
                        indx(m,ii,iiens,k) = 3e33
                    endif
                else
                    if ( data(j,i,iens) < 1e33 .and. indx(m,ii,jens,k) < 1e33 ) then
                        data(j,i,iiens) = a(2) + a(1)*indx(m,ii,jens,k) + sd*eta
                    else
                        data(j,i,iiens) = 3e33
                    endif
                endif
            enddo
        710 continue
        enddo
    enddo
end subroutine makemcseries

subroutine make1mcseries(alpha,sd,data,npermax,nperyear,yrbeg &
    ,yrend,nens1,nens2,j1,j2,yrstart,yrstop,lwrite)

!   make an AR(1) series with standard deviation sd and lag-1
!   autocorrelation alpha in the position of data that are not undefined

    implicit none
    integer :: npermax,nperyear,yrbeg,yrend,nens1,nens2,j1,j2,yrstart,yrstop
    real :: alpha,sd,data(npermax,yrbeg:yrend,0:nens2)
    logical :: lwrite
    integer :: iens,yr,mo,yr1,mo1,nprev
    real,external :: gasdev

    if ( j1 /= j2 ) then
!       consecutive months (seasons, weeks, ...)
        do iens=nens1,nens2
            nprev = -999
            do yr=yrstart,yrstop
                do mo=1,nperyear
                    if ( nprev /= -999 ) then
                        nprev = nprev + 1
                    endif
                    if ( mo < j1 .or. mo > j2 .or. data(mo,yr,iens) > 1e33 ) then
                        cycle
                    endif   ! valid data
                    if ( nprev == -999 ) then ! first point
                        data(mo,yr,iens) = &
                        sd*gasdev(mo+100*yr+10000*iens)
                    else
                        mo1 = mo - nprev
                        call normon(mo1,yr,yr1,nperyear)
                        data(mo,yr,iens) = alpha**nprev *data(mo1,yr1,iens) &
                            + sd*sqrt(1-(alpha**nprev)**2)*gasdev(mo+100*yr+10000*iens)
                    endif
                    nprev = 0
                enddo       ! mo
            enddo           ! yr
        enddo               ! iens
    else
!       consecutive years
        do iens=nens1,nens2
            nprev = -999
            do yr=yrstart,yrstop
                if ( nprev /= -999 ) then
                    nprev = nprev + 1
                endif
                if ( data(j1,yr,iens) > 1e33 ) then
                    cycle
                endif       ! valid data
                if ( nprev == -999 ) then ! first point
                    data(j1,yr,iens) = sd*gasdev(yr+100*iens)
                else
                    yr1 = yr - nprev
                    data(j1,yr1,iens) = alpha**nprev *data(j1,yr1,iens) &
                        + sd*sqrt(1-(alpha**nprev)**2)*gasdev(yr+100*iens)
                endif
                nprev = 0
            enddo           ! yr
        enddo               ! iens
    endif
end subroutine make1mcseries

