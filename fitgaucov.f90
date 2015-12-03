subroutine fitgaucov(yrseries,yrcovariate,npernew,fyr,lyr &
     &       ,mens1,mens,crosscorr,a3,b3,alpha3,beta3,j1,j2 &
     &       ,lweb,ntype,lchangesign,yr1a,yr2a,xyear,idmax,cov1,cov2 &
     &       ,offset,t3,tx3,assume,confidenceinterval,ndecor,lboot &
     &       ,lprint,dump,plot,lwrite)
!
!   a fit a gaussian distribution with mean linearly dependent on a covariate 
!   to the data
!
    implicit none
!
    integer npernew,fyr,lyr,mens1,mens,ntot,ntype,j1,j2,yr1a,yr2a,ndecor
    real yrseries(npernew,fyr:lyr,0:mens), &
     &       yrcovariate(npernew,fyr:lyr,0:mens),crosscorr(0:mens,0:mens), &
     &       a3(3),b3(3),alpha3(3),beta3(3),xyear,cov1,cov2, &
     &       offset,t3(3,10,3),tx3(3,3),confidenceinterval
    logical lweb,lchangesign,lboot,lprint,dump,plot,lwrite
    character assume*(*),idmax*(*)
!
    integer nmc
    parameter(nmc=1000)
    integer i,j,jj,n,nx,iter,iens,nfit,imc,ier,year
    integer,allocatable :: yrs(:)
    real a,b,t(10,3),t25(10,3),t975(10,3),tx(3),tx25(3),tx975(3), &
     &       aa(nmc),bb(nmc),tt(nmc,10,3),xi,alpha,beta,dalpha,dbeta, &
     &       xmin,z,x,f,txtx(nmc,3),alphaalpha(nmc),betabeta(nmc), &
     &       mean,sd,ranf,mindata,minindx,pmindata,snorm,s,frac,scross,sdecor
    real a25,a975,b25,b975,alpha25,alpha975,beta25,beta975
    real adev,var,skew,curt,aaa,bbb,siga,chi2,q,cmin,cmax,plo,phi
    real ttt(10,3),txtxtx(3),dum,xi3(3),acov(3,2),aacov(nmc,2)
    real,allocatable :: xx(:,:),yy(:),ys(:),zz(:),sig(:)
    character lgt*4,method*3
    external gaucovreturnlevel,gaucovreturnyear
!
    integer nmax
    parameter(nmax=100000)
    integer ncur
    real data(2,nmax),restrain
    logical llwrite
    common /fitdata3/ data
    common /fitdata2/ restrain,ncur,llwrite
    character cassume*5
    common /fitdata4/ cassume
!
    year = yr2a
    allocate(yrs(0:nmax))
    allocate(xx(2,nmax))

    if ( lwrite ) print *,'fitgaucov: calling fill_linear_array'
    call fill_linear_array(yrseries,yrcovariate,npernew,j1,j2, &
     &       fyr,lyr,mens1,mens,xx,yrs,nmax,ntot,lwrite)
    if ( lprint .and. lweb ) then
        print '(a,i9,a)','# <tr><td>N:</td><td>&nbsp;</td><td>', &
     &           ntot,'</td><td>&nbsp;</td></tr>'
    end if

    if ( lwrite ) then
        print *,'fitgaucov: input'
        print *,'year,xyear  = ',year,xyear
        print *,'cov1,cov2,offset ',cov1,cov2,offset
    end if
    if ( ntot.eq.0 ) then
        if ( lwrite ) print *,'fitgaucov: ntot=0'
        a3 = 3e33
        b3 = 3e33
        xi3 = 0
        alpha3 = 3e33
        beta3 = 3e33
        t3 = 3e33
        tx3 = 3e33
        return
    endif
!
!   compute first-guess parameters
!
    allocate(yy(ntot))
    allocate(ys(ntot))
    allocate(zz(ntot))
    allocate(sig(ntot))
    cmin = 3e33
    cmax = -3e33
    do i=1,ntot
        yy(i) = xx(1,i)
        zz(i) = xx(2,i)
        cmin = min(cmin,xx(2,i))
        cmax = max(cmax,xx(2,i))
    end do
    call write_obscov(xx,yrs,ntot,-3e33,cov2,xyear,year,offset,lchangesign)
!
    sig = 0
    call moment(yy,ntot,mean,adev,sd,var,skew,curt)
    call fit(zz,yy,ntot,sig,0,aaa,alpha,siga,dalpha,chi2,q)
    if ( lwrite ) then
        print *,'fitgaucov: computed initialisation values:'
        print *,'mean,sd,alpha,dalpha = ',mean,sd,alpha,dalpha
    end if
!
!   a trivial case which causes no end of trouble
!
    if ( sd.eq.0 ) then
        if ( lwrite ) print *,'fitgaucov: sd=0, everything undfined'
        a3 = 3e33
        b3 = 3e33
        xi3 = 0
        alpha3 = 3e33
        beta3 = 3e33
        t3 = 3e33
        tx3 = 3e33
        return
    endif
!
!   copy to common for routine llgausscov
!
    ncur = ntot
    do i=1,ncur
        data(:,i) = xx(:,i)
    enddo
    cassume = assume
!   
!   fit, using Numerical Recipes routines
!
    a = mean
    b = sd
    if ( assume.eq.'shift' .or. assume.eq.'scale' ) then
        beta = 3e33
        call fit1gaucov(a,b,alpha,dalpha,iter)
    else if ( assume.eq.'both' ) then
        call fit2gaucov(a,b,alpha,beta,dalpha,dbeta,iter)
    else
        write(0,*) 'fitgaucov: cannot handle assume = ',assume
        call abort
    end if
    dum = 0
    call getreturnlevels(a,b,dum,alpha,beta,cov1,cov2,gaucovreturnlevel,j1,j2,t)
    if ( xyear.lt.1e33 ) then
        call getreturnyears(a,b,dum,alpha,beta,xyear,cov1,cov2,gaucovreturnyear,j1,j2,tx, &
        &   lchangesign,lwrite)
    endif
    call getabfromcov(a,b,alpha,beta,cov1,aaa,bbb)
    acov(1,1) = aaa
    call getabfromcov(a,b,alpha,beta,cov2,aaa,bbb)
    acov(1,2) = aaa
    call write_threshold(cmin,cmax,a,b,alpha,beta,offset,lchangesign)
!
!   Bootstrap for error estimate
!
    if ( .not.lboot ) then
        if ( lchangesign ) then
            a = -a
            acov = -acov
            aacov = -aacov
            t = -t
            alpha = -alpha
            beta = -beta
        endif
        a3(1) = a
        a3(2:3) = 3e33
        b3(1) = b
        b3(2:3) = 3e33
        xi3 = 0
        alpha3(1) = alpha
        alpha3(2:3) = 3e33
        beta3(1) = beta
        beta3(2:3) = 3e33
        t3(1,:,:) = t(:,:)
        t3(2:3,:,:) = 3e33
        tx3(1,:) = tx(:)
        tx3(2:3,:) = 3e33            
        return
    endif
    if ( lprint .and. .not.lweb ) print '(a,i6,a)','# doing a ',nmc &
     &        ,'-member bootstrap to obtain error estimates'
    scross = 0
    do iens=1,nmc
        if ( lprint .and. .not.lweb .and. mod(iens,100).eq.0 ) print '(a,i6)','# ',iens
        method = 'new'
        if ( method == 'old' ) then
            n = 1 + (ntot-1)/ndecor
            do i=1,n
                ! we do not have the information here to check whether the
                ! data points were contiguous in the original series...
                ! TODO: propagate that information              
                call random_number(ranf)
                j = 1 + min(ntot-ndecor,int((ntot-ndecor)*ranf))
                if ( j.lt.1 .or. j.gt.ntot ) then
                    write(0,*) 'fitgaucov: error: j = ',j
                    call abort
                endif
                if ( i.lt.n ) then ! the blocks that fit in whole
                    do jj=0,ndecor-1
                        data(:,1+(i-1)*ndecor+jj) = xx(:,j+jj)
                    end do
                else
                    do jj=0,ndecor-1 ! one more block to the end, the previous block is shortened
                        data(:,1+ntot-ndecor+jj) = xx(:,j+jj)
                    end do
                end if
            enddo
        else
            call sample_bootstrap(yrseries,yrcovariate, &
     &               npernew,j1,j2,fyr,lyr,mens1,mens,crosscorr, &
     &               ndecor,data,nmax,ntot,sdecor,lwrite)
            scross = scross + sdecor
        end if
        aa(iens) = a
        bb(iens) = b
        alphaalpha(iens) = alpha
        llwrite = .false.
        if ( assume.eq.'shift' .or. assume.eq.'scale' ) then
            betabeta(iens) = 3e33
            call fit1gaucov(aa(iens),bb(iens),alphaalpha(iens),dalpha,iter)
        else if ( assume.eq.'both' ) then
            betabeta(iens) = beta
            call fit2gaucov(aa(iens),bb(iens),alphaalpha(iens),betabeta(iens),dalpha,dbeta,iter)
        else
            write(0,*) 'fitgaucov: cannot handle assume = ',assume
            call abort
        end if
        call getabfromcov(aa(iens),bb(iens),alphaalpha(iens),betabeta(iens),cov1,aaa,bbb)
        aacov(iens,1) = aaa
        call getabfromcov(aa(iens),bb(iens),alphaalpha(iens),betabeta(iens),cov2,aaa,bbb)
        aacov(iens,2) = aaa
        call getreturnlevels(aa(iens),bb(iens),dum, &
     &           alphaalpha(iens),betabeta(iens), &
     &           cov1,cov2,gaucovreturnlevel,j1,j2,ttt)
        do i=1,10
            do j=1,3
                tt(iens,i,j) = ttt(i,j)
            end do
        end do
        if ( xyear.lt.1e33 ) then
            call getreturnyears(aa(iens),bb(iens),dum, &
     &               alphaalpha(iens),betabeta(iens),xyear,cov1,cov2, &
     &               gaucovreturnyear,j1,j2,txtxtx,lchangesign,lwrite)
            do j=1,3
                txtx(iens,j) = txtxtx(j)
            end do
        endif
    enddo
    if ( mens > mens1 ) call print_spatial_scale(scross/nmc)
    iens = nmc
    if ( lchangesign ) then
        a = -a
        acov = -acov
        aa = -aa
        aacov = -aacov
        alpha = -alpha
        alphaalpha = -alphaalpha
        t = -t
        tt = -tt
    endif
    plo = (100-confidenceinterval)/2
    phi = (100+confidenceinterval)/2
    call getcut( a25,plo,nmc,aa)
    call getcut(a975,phi,nmc,aa)
    call getcut( b25,plo,nmc,bb)
    call getcut(b975,phi,nmc,bb)
    call getcut( alpha25,plo,nmc,alphaalpha)
    call getcut(alpha975,phi,nmc,alphaalpha)
    if ( assume.eq.'both' ) then
        call getcut( beta25,plo,nmc,betabeta)
        call getcut(beta975,phi,nmc,betabeta)
    end if
    do i=1,10
        do j=1,3
            call getcut( t25(i,j),plo,nmc,tt(1,i,j))
            call getcut(t975(i,j),phi,nmc,tt(1,i,j))
        enddo
    end do
    do j=1,3
        if ( xyear.lt.1e33 ) then
            call getcut( tx25(j),plo,nmc,txtx(1,j))
            call getcut(tx975(j),phi,nmc,txtx(1,j))
            if ( lchangesign ) xyear = -xyear
        endif
    end do
    call getcut(acov(2,1),plo,iens,aacov(1,1))
    call getcut(acov(3,1),phi,iens,aacov(1,1))
    call getcut(acov(2,2),plo,iens,aacov(1,2))
    call getcut(acov(3,2),phi,iens,aacov(1,2))
    call write_dthreshold(cov1,cov2,acov,offset,lchangesign)
!
!   output
!
    if ( .not.lprint ) then
        xi = 0
        call copyab3etc(a3,b3,xi3,alpha3,beta3,t3,tx3, &
     &           a,a25,a975,b,b975,xi,xi,xi,alpha,alpha25,alpha975, &
     &           beta,beta25,beta975,t,t25,t975,tx,tx25,tx975)
        if ( .not.lwrite ) return
    end if
    if ( lweb ) then
        print '(a)','# <tr><td colspan="4">Fitted to normal '// &
     &           'distribution P(x) = exp(-(x-a'')&sup2;'// &
     &           '/(2b''&sup2;))/(b''&radic;(2&pi;))</td></tr>'
        call printab(lweb)
        print '(a,f16.3,a,f16.3,a,f16.3,a)','# <tr><td colspan=2>'// &
     &           'a:</td><td>',a,'</td><td>',a25,'...',a975,'</td></tr>'
        print '(a,f16.3,a,f16.3,a,f16.3,a)','# <tr><td colspan=2>'// &
     &           'b:</td><td>',b,'</td><td>',b25,'...',b975,'</td></tr>'
        print '(a,f16.3,a,f16.3,a,f16.3,a)','# <tr><td colspan=2>'// &
     &           '&alpha;:</td><td>',alpha,'</td><td>',alpha25,'...', &
     &           alpha975,'</td></tr>'
        if ( assume.eq.'both' ) then
            print '(a,f16.3,a,f16.3,a,f16.3,a)', &
     &               '# <tr><td colspan=2>&beta;:</td><td>',beta, &
     &               '</td><td>',beta25,'...',beta975,'</td></tr>'
        end if
    else
        print '(a,i5,a)','# Fitted to Gaussian distribution in ',iter,' iterations'
        print '(a)','# p(x) = exp(-(x-a'')^2/(2*b''^2))/(b''*sqrt(2*pi)) with'
        call printab(lweb)
        print '(a,f16.3)','# a = ',a
        print '(a,f16.3)','# b = ',b
        print '(a,f16.3)','# alpha = ',alpha
        if ( assume.eq.'both' ) then
            print '(a,f16.3,a,f16.3,a,f16.3)','# beta  ',beta,' \\pm ',beta975-beta25
        end if
    endif
    call printcovreturnvalue(ntype,t,t25,t975,yr1a,yr2a,lweb,plot)
    call printcovreturntime(year,xyear,idmax,tx,tx25,tx975,yr1a,yr2a,lweb,plot)
    call printcovpvalue(txtx,nmc,nmc,lweb)

    if ( dump ) then
        call plot_tx_cdfs(txtx,nmc,nmc,ntype,j1,j2)
    end if
    if ( plot ) write(11,'(3g20.4,a)') alpha,alpha25,alpha975,' alpha'

    ! no cuts
    mindata = -2e33
    minindx = -2e33
    pmindata = -1
    snorm = 1
    frac = 1
    ! fit to gauss (normal distribution)
    nfit = 2
    if ( lchangesign ) b = -b

    ! compute distribution at past year and plot it
    call adjustyy(ntot,xx,assume,a,b,alpha,beta,cov1,yy,zz,aaa,bbb,lchangesign,lwrite)
    ys(1:ntot) = yy(1:ntot)
    print '(a,i5)','# distribution in year ',yr1a
    call plotreturnvalue(ntype,t25(1,1),t975(1,1),j2-j1+1)
    call plot_ordered_points(yy,ys,yrs,ntot,ntype,nfit, &
     &       frac,aaa,bbb,dum,j1,j2,minindx,mindata,pmindata, &
     &       year,xyear,snorm,lchangesign,lwrite,.false.)

    ! compute distribution at present year and plot it
    call adjustyy(ntot,xx,assume,a,b,alpha,beta,cov2,yy,zz,aaa,bbb,lchangesign,lwrite)
    ys(1:ntot) = yy(1:ntot)
    print '(a)'
    print '(a)'
    print '(a,i5)','# distribution in year ',yr2a
    call plotreturnvalue(ntype,t25(1,2),t975(1,2),j2-j1+1)
    call plot_ordered_points(yy,ys,yrs,ntot,ntype,nfit, &
     &       frac,aaa,bbb,dum,j1,j2,minindx,mindata,pmindata, &
     &       year,xyear,snorm,lchangesign,lwrite,.true.)
end subroutine

subroutine fit1gaucov(a,b,alpha,dalpha,iter)
    implicit none
    integer iter
    real a,b,alpha,dalpha
    integer i
    real q(4),p(4,3),y(4),tol
    real llgausscov
    external llgausscov
!
!   fit, using Numerical Recipes routines
!   
    q(1) = a
    q(2) = b
    q(3) = alpha
    q(4) = 3e33
    p(1,1) = q(1) *0.9
    p(1,2) = q(2) *0.9
    p(1,3) = q(3) - dalpha
    p(2,1) = p(1,1) *1.2
    p(2,2) = p(1,2)
    p(2,3) = p(1,3)
    p(3,1) = p(1,1)
    p(3,2) = p(1,2) *1.2
    p(3,3) = p(1,3)
    p(4,1) = p(1,1)
    p(4,2) = p(1,2)
    p(4,3) = p(1,3) + 2*dalpha
    do i=1,4
        q(1) = p(i,1)
        q(2) = p(i,2)
        q(3) = p(i,3)
        y(i) = llgausscov(q)
    enddo
    tol = 1e-4
    call amoeba(p,y,4,3,3,tol,llgausscov,iter)
!   maybe add restart later
    a = p(1,1)
    b = p(1,2)
    alpha = p(1,3)
end subroutine

subroutine fit2gaucov(a,b,alpha,beta,dalpha,dbeta,iter)
    implicit none
    integer iter
    real a,b,alpha,beta,dalpha,dbeta
    integer i
    real q(4),p(5,4),y(5),tol
    real llgausscov
    external llgausscov
!
!   fit, using Numerical Recipes routines
!   
    q(1) = a
    q(2) = b
    q(3) = alpha
    q(4) = beta
    p(1,1) = q(1) *0.9
    p(1,2) = q(2) *0.9
    p(1,3) = q(3) - dalpha
    p(1,4) = q(4) - dbeta
    p(2,1) = p(1,1) *1.2
    p(2,2) = p(1,2)
    p(2,3) = p(1,3)
    p(2,4) = p(1,4)
    p(3,1) = p(1,1)
    p(3,2) = p(1,2) *1.2
    p(3,3) = p(1,3)
    p(3,4) = p(1,4)
    p(4,1) = p(1,1)
    p(4,2) = p(1,2)
    p(4,3) = p(1,3) + 2*dalpha
    p(4,4) = p(1,4)
    p(5,1) = p(1,1)
    p(5,2) = p(1,2)
    p(5,3) = p(1,3)
    p(5,4) = p(1,4) + 2*dbeta
    do i=1,5
        q(1) = p(i,1)
        q(2) = p(i,2)
        q(3) = p(i,3)
        q(4) = p(i,4)
        y(i) = llgausscov(q)
    enddo
    tol = 1e-4
    call amoeba(p,y,5,4,4,tol,llgausscov,iter)
!   maybe add restart later
    a = p(1,1)
    b = p(1,2)
    alpha = p(1,3)
    beta = p(1,4)
end subroutine

real function llgausscov(p)
!
!   computes the log-likelihood function for a normal distribution
!   with parameters alpha,beta=p(1),p(2) and data in common.
!
    implicit none
!   
    real p(4)
!
    integer i
    real z,s,aa,bb
!
    integer nmax
    parameter(nmax=100000)
    integer ncur
    real data(2,nmax),restrain
    logical llwrite
    common /fitdata3/ data
    common /fitdata2/ restrain,ncur,llwrite
    character cassume*5
    common /fitdata4/ cassume
!   
    llgausscov = 0
    do i=1,ncur
        call getabfromcov(p(1),p(2),p(3),p(4),data(2,i),aa,bb)
        z = (data(1,i) - aa)/bb
        llgausscov = llgausscov - z**2/2 - log(abs(bb))
    enddo
!   normalization is not 1 in case of cut-offs
    call gauscovnorm(aa,bb,s)
    llgausscov = llgausscov - ncur*log(s)
!   minimum, not maximum
    llgausscov = -llgausscov
!!!        print *,'a,b,llgausscov = ',p(1),p(2),llgausscov
!
end function

subroutine gauscovnorm(a,b,s)
    implicit none
    include 'getopts.inc'
    real a,b,s
    real z1,z2,sqrt2
    real erfcc
    external erfcc
    if ( minindx.gt.-1e33 .or. maxindx.lt.1e33 ) then
        write(0,*) 'gauscovnorm: boundaries not yet available for fit of gauss(t)'
        call abort
    else
        s = 1
    endif
!!!        print *,'gauscovnorm: norm = ',a,b,s
end subroutine

real function gaucovreturnlevel(a,b,xi,alpha,beta,x,cov)
!
!   compute return times given the normal distribution parameters a,b and 
!   x = log10(returntime) for covariant cov and fit parameter alpha
!
    implicit none
    real a,b,xi,alpha,beta,x,cov
    integer ier
    real aa,bb,f,z,t
!
    call getabfromcov(a,b,alpha,beta,cov,aa,bb)
    f = 10.**x
    f = 1-2/f
    call merfi(f,z,ier)
    t = aa + sqrt(2.)*bb*z
    gaucovreturnlevel = t
end function

real function gaucovreturnyear(a,b,xi,alpha,beta,xyear,cov,lchangesign)
!
!   compute the return time of the value xyear with the fitted values
!
    implicit none
    real a,b,xi,alpha,beta,xyear,cov
    logical lchangesign
    real z,tx,aa,bb
    real erfc

    call getabfromcov(a,b,alpha,beta,cov,aa,bb)        
    z = (xyear - aa)/bb
    if ( z.gt.12 ) then
        tx = 3e33
    else
        tx = 2/erfc(z/sqrt(2.))
    end if
    gaucovreturnyear = tx
end function