      implicit real *8 (a-h,o-z) 
      real *8, allocatable :: srcvals(:,:),srccoefs(:,:)
      real *8, allocatable :: wts(:),rsigma(:)
      integer ipars(2)
      integer, allocatable :: ipatch_id(:)
      real *8, allocatable :: uvs_targ(:,:)
      real *8 dpars(2)

      integer, allocatable :: norders(:),ixyzs(:),iptype(:)

      real *8 xyz_out(3),xyz_in(3)
      complex *16, allocatable :: rhs(:)
      complex *16, allocatable :: psinm(:,:),phinm(:,:),dfuv(:,:)
      complex *16, allocatable :: vynm(:,:)

      complex *16, allocatable :: vynm_targ(:,:)
      complex *16, allocatable :: phinm_targ(:,:)
      complex *16, allocatable :: psinm_targ(:,:)
      
      complex *16, allocatable :: wnear(:,:)
      real *8, allocatable :: targs(:,:)

      real *8, allocatable :: cms(:,:),rads(:),rad_near(:)

      integer, allocatable :: col_ptr(:),row_ind(:)
      integer, allocatable :: ixyzso(:),novers(:)
      integer, allocatable :: row_ptr(:),col_ind(:),iquad(:)

      complex *16, allocatable :: ecomp(:,:),eex(:,:)

      complex *16 zalpha,zbeta,zgamma,zdelta,zeta,zteta,zk,ztetap
      complex *16 ztetam
      complex *16 fjvals(0:100),fhvals(0:100),fjder(0:100),fhder(0:100)
      complex *16 fjvalst(0:100),fhvalst(0:100)
      complex *16 fjdert(0:100),fhdert(0:100)
      complex *16 z1,z2,z3,z4
      complex *16 zvec1(3),zvec2(3),zvec3(3)
      real *8 dvec1(3),dvec2(3),dvec3(3)

      real *8 thet,phi,eps_gmres
      complex * 16 zpars(3)
      integer numit,niter
      character *100 title,dirname
      character *300 fname

      real *8, allocatable :: w(:,:)

      logical isout0,isout1

      complex *16 ztmp,ima
      procedure (), pointer :: fker
      external h3d_sgradx, h3d_sgrady, h3d_sgradz,h3d_slp

      data ima/(0.0d0,1.0d0)/


      call prini(6,13)

      done = 1
      pi = atan(done)*4


      igeomtype = 1
      ipars(1) = 2 
      npatches=12*(4**ipars(1))

      norder = 8 
      npols = (norder+1)*(norder+2)/2

      npts = npatches*npols
      allocate(srcvals(12,npts),srccoefs(9,npts))
      ifplot = 0

      call setup_geom(igeomtype,norder,npatches,ipars, 
     1       srcvals,srccoefs,ifplot,fname)

      allocate(norders(npatches),ixyzs(npatches+1),iptype(npatches))

      do i=1,npatches
        norders(i) = norder
        ixyzs(i) = 1 +(i-1)*npols
        iptype(i) = 1
      enddo

      print *, 'npts=',npts

      ixyzs(npatches+1) = 1+npols*npatches
      allocate(wts(npts))
      call get_qwts(npatches,norders,ixyzs,iptype,npts,srcvals,wts)


c
c       define rhs to be one of the ynm's
c
      nn = 3
      mm = 1
      nmax = nn
      allocate(w(0:nmax,0:nmax))
      allocate(rhs(npts))
      call l3getsph(nmax,mm,nn,12,srcvals,rhs,npts,w)
c
c  set the value of dzk
c
      zk = 0.19d0


      njh = 5
      ifder = 1
      rscale = 1.0d0
      call prin2('zk=*',zk,2)
      call besseljs3d(njh,zk,rscale,fjvals,ifder,fjder)
      call h3dall(njh,zk,rscale,fhvals,ifder,fhder)


      allocate(dfuv(2,npts))

      call get_surf_grad(2,npatches,norders,ixyzs,iptype,npts,
     1  srccoefs,srcvals,rhs,dfuv)


      allocate(psinm(3,npts),phinm(3,npts),vynm(3,npts))
      do i=1,npts
        psinm(1:3,i) = dfuv(1,i)*srcvals(4:6,i) + 
     1     dfuv(2,i)*srcvals(7:9,i) 
        call dzcross_prod3d(srcvals(10,i),psinm(1,i),phinm(1,i))
      enddo

      call prin2('psinm=*',psinm,24)
      call prin2('phinm=*',phinm,24)

cc      call l3getsph_vec(mm,nn,12,npts,srcvals,vynm,psinm,
cc     1   phinm)
cc      call prin2('psinm=*',psinm,24)
cc      call prin2('phinm=*',phinm,24)

      eps = 0.51d-10

      
c
c       precompute near quadrature correction
c
c
      iptype_avg = floor(sum(iptype)/(npatches+0.0d0))
      norder_avg = floor(sum(norders)/(npatches+0.0d0))

      call get_rfacs(norder_avg,iptype_avg,rfac,rfac0)

      ntargin = 1
      ntargout = 1
      ntarg = ntargin + ntargout
      allocate(targs(3,ntarg))
      allocate(ipatch_id(ntarg),uvs_targ(2,ntarg))
      do i=1,ntarg
        r = hkrand(0)*0.8d0
        thet = hkrand(0)*pi
        phi = hkrand(0)*2*pi

        r = 0.999d0

        if(i.gt.ntargin) then
          r = hkrand(0)*0.8 + 1.2d0
          r = 1.2d0
        endif

        targs(1,i) = r*sin(thet)*cos(phi)
        targs(2,i) = r*sin(thet)*sin(phi)
        targs(3,i) = r*cos(thet)

        ipatch_id(i) = -1
        uvs_targ(1,i) = 0
        uvs_targ(2,i) = 0
      enddo

      nnz = ntarg*npatches
      allocate(row_ptr(ntarg+1),col_ind(nnz))

      do i=1,ntarg
        row_ptr(i) = (i-1)*npatches + 1
        do j=1,npatches
          col_ind(row_ptr(i)+j-1) = j
        enddo
      enddo
      row_ptr(ntarg+1) = ntarg*npatches+1
      allocate(iquad(nnz+1))
      call prinf('npatches=*',npatches,1)
      call prinf('ntarg=*',ntarg,1)
      call prinf('nnz=*',nnz,1)
      
      call get_iquad_rsc(npatches,ixyzs,ntarg,nnz,row_ptr,col_ind,
     1         iquad)

      nquad = iquad(nnz+1)-1


      allocate(wnear(nquad,4))
      
      do j=1,4
C$OMP PARALLEL DO DEFAULT(SHARED)      
        do i=1,nquad
          wnear(i,j) = 0
        enddo
      enddo
C$OMP END PARALLEL DO    

      iquadtype = 1
      ndz = 1
      ndi = 0
      ndd = 0

      ipv = 1
      
      fker => h3d_sgradx
      call zgetnearquad_ggq_guru(npatches,norders,ixyzs,iptype,
     1  npts,srccoefs,srcvals,3,ntarg,targs,ipatch_id,uvs_targ,eps,
     2  ipv,fker,ndd,dpars,ndz,zk,ndi,ipars,nnz,row_ptr,col_ind,iquad,
     3  rfac0,nquad,wnear(1,1))

      fker => h3d_sgrady
      call zgetnearquad_ggq_guru(npatches,norders,ixyzs,iptype,
     1  npts,srccoefs,srcvals,3,ntarg,targs,ipatch_id,uvs_targ,eps,
     2  ipv,fker,ndd,dpars,ndz,zk,ndi,ipars,nnz,row_ptr,col_ind,iquad,
     3  rfac0,nquad,wnear(1,2))

      fker => h3d_sgradz
      call zgetnearquad_ggq_guru(npatches,norders,ixyzs,iptype,
     1  npts,srccoefs,srcvals,3,ntarg,targs,ipatch_id,uvs_targ,eps,
     2  ipv,fker,ndd,dpars,ndz,zk,ndi,ipars,nnz,row_ptr,col_ind,iquad,
     3  rfac0,nquad,wnear(1,3))
      
      fker => h3d_slp
      call zgetnearquad_ggq_guru(npatches,norders,ixyzs,iptype,
     1  npts,srccoefs,srcvals,3,ntarg,targs,ipatch_id,uvs_targ,eps,
     2  ipv,fker,ndd,dpars,ndz,zk,ndi,ipars,nnz,row_ptr,col_ind,iquad,
     3  rfac0,nquad,wnear(1,4))
      

      allocate(eex(3,ntarg),ecomp(3,ntarg))

c
c  test s[psinm]
c
      do i=1,ntarg
        ecomp(1:3,i) = 0
        do j=row_ptr(i),row_ptr(i+1)-1
          jpatch = col_ind(j)
          npols = ixyzs(jpatch+1)-ixyzs(jpatch)
          jquadstart = iquad(j)
          jstart = ixyzs(jpatch)
          do l=1,npols
            ecomp(1:3,i) = ecomp(1:3,i) + wnear(jquadstart+l-1,4)*
     1          psinm(1:3,jstart+l-1)
          enddo
        enddo
      enddo


      allocate(vynm_targ(3,ntarg),phinm_targ(3,ntarg))
      allocate(psinm_targ(3,ntarg))


      call l3getsph_vec(mm,nn,3,ntarg,targs,vynm_targ,psinm_targ,
     1   phinm_targ)

      erra = 0
      ra = 0
      do i=1,ntargin
        r = sqrt(targs(1,i)**2 + targs(2,i)**2 + targs(3,i)**2)
        z1 = zk*r
        call besseljs3d(njh,z1,rscale,fjvalst,ifder,fjdert)
        z2 = ima*nn*(nn+1.0d0)*(fjvalst(nn)/r*(fhvals(nn) +
     1       zk*fhder(nn)) + fjdert(nn)*fhvals(nn)*zk)/zk
        z3 = (ima*(zk**2*fjdert(nn) + fjvalst(nn)*zk/r)*(fhvals(nn) + 
     1       zk*fhder(nn)) +
     2       ima*nn*(nn+1.0d0)*zk*fhvals(nn)*fjvalst(nn)/r)/zk**2
        eex(1:3,i) = psinm_targ(1:3,i)*z3 + vynm_targ(1:3,i)*z2
        erra = erra + abs(eex(1,i)-ecomp(1,i))**2
        erra = erra + abs(eex(2,i)-ecomp(2,i))**2
        erra = erra + abs(eex(3,i)-ecomp(3,i))**2
        ra = ra + abs(eex(1,i))**2
        ra = ra + abs(eex(2,i))**2
        ra = ra + abs(eex(3,i))**2
      enddo

      erra = sqrt(erra/ra)
      call prin2('error in S[\psinm]=*',erra,1)

      erra = 0
      ra = 0
      do i=ntargin+1,ntarg
        r = sqrt(targs(1,i)**2 + targs(2,i)**2 + targs(3,i)**2)
        z1 = zk*r
        call h3dall(njh,z1,rscale,fhvalst,ifder,fhdert)
        z2 = ima*nn*(nn+1.0d0)*(fhvalst(nn)/r*(fjvals(nn) +
     1       zk*fjder(nn)) + fhdert(nn)*fjvals(nn)*zk)/zk
        z3 = (ima*(zk**2*fhdert(nn) + fhvalst(nn)*zk/r)*(fjvals(nn) + 
     1       zk*fjder(nn)) +
     2       ima*nn*(nn+1.0d0)*zk*fjvals(nn)*fhvalst(nn)/r)/zk**2
        eex(1:3,i) = psinm_targ(1:3,i)*z3 + vynm_targ(1:3,i)*z2
        erra = erra + abs(eex(1,i)-ecomp(1,i))**2
        erra = erra + abs(eex(2,i)-ecomp(2,i))**2
        erra = erra + abs(eex(3,i)-ecomp(3,i))**2
        ra = ra + abs(eex(1,i))**2
        ra = ra + abs(eex(2,i))**2
        ra = ra + abs(eex(3,i))**2
      enddo

      erra = sqrt(erra/ra)
      call prin2('error in exterior S[\psinm]=*',erra,1)


c
c  test s[phinm]
c
      do i=1,ntarg
        ecomp(1:3,i) = 0
        do j=row_ptr(i),row_ptr(i+1)-1
          jpatch = col_ind(j)
          npols = ixyzs(jpatch+1)-ixyzs(jpatch)
          jquadstart = iquad(j)
          jstart = ixyzs(jpatch)
          do l=1,npols
            ecomp(1:3,i) = ecomp(1:3,i) + wnear(jquadstart+l-1,4)*
     1          phinm(1:3,jstart+l-1)
          enddo
        enddo
      enddo

      erra = 0
      ra = 0
      do i=1,ntargin
        r = sqrt(targs(1,i)**2 + targs(2,i)**2 + targs(3,i)**2)
        z1 = zk*r
        call besseljs3d(njh,z1,rscale,fjvalst,ifder,fjdert)
        z2 = ima*fjvalst(nn)*zk*fhvals(nn)
        eex(1:3,i) = phinm_targ(1:3,i)*z2 
        erra = erra + abs(eex(1,i)-ecomp(1,i))**2
        erra = erra + abs(eex(2,i)-ecomp(2,i))**2
        erra = erra + abs(eex(3,i)-ecomp(3,i))**2
        ra = ra + abs(eex(1,i))**2
        ra = ra + abs(eex(2,i))**2
        ra = ra + abs(eex(3,i))**2
      enddo

      erra = sqrt(erra/ra)
      call prin2('error in S[\phinm]=*',erra,1)

      erra = 0
      ra = 0
      do i=ntargin+1,ntarg
        r = sqrt(targs(1,i)**2 + targs(2,i)**2 + targs(3,i)**2)
        z1 = zk*r
        call h3dall(njh,z1,rscale,fhvalst,ifder,fhdert)
        z2 = ima*fjvals(nn)*zk*fhvalst(nn)
        eex(1:3,i) = phinm_targ(1:3,i)*z2 
        erra = erra + abs(eex(1,i)-ecomp(1,i))**2
        erra = erra + abs(eex(2,i)-ecomp(2,i))**2
        erra = erra + abs(eex(3,i)-ecomp(3,i))**2
        ra = ra + abs(eex(1,i))**2
        ra = ra + abs(eex(2,i))**2
        ra = ra + abs(eex(3,i))**2
      enddo

      erra = sqrt(erra/ra)
      call prin2('error in exterior S[\phinm]=*',erra,1)


      stop
      end




      subroutine setup_geom(igeomtype,norder,npatches,ipars, 
     1    srcvals,srccoefs,ifplot,fname)
      implicit real *8 (a-h,o-z)
      integer igeomtype,norder,npatches,ipars(*),ifplot
      character (len=*) fname
      real *8 srcvals(12,*), srccoefs(9,*)
      real *8, allocatable :: uvs(:,:),umatr(:,:),vmatr(:,:),wts(:)

      real *8, pointer :: ptr1,ptr2,ptr3,ptr4
      integer, pointer :: iptr1,iptr2,iptr3,iptr4
      real *8, target :: p1(10),p2(10),p3(10),p4(10)
      real *8, allocatable, target :: triaskel(:,:,:)
      real *8, allocatable, target :: deltas(:,:)
      integer, allocatable :: isides(:)
      integer, target :: nmax,mmax

      procedure (), pointer :: xtri_geometry


      external xtri_stell_eval,xtri_sphere_eval
      
      npols = (norder+1)*(norder+2)/2
      allocate(uvs(2,npols),umatr(npols,npols),vmatr(npols,npols))
      allocate(wts(npols))

      call vioreanu_simplex_quad(norder,npols,uvs,umatr,vmatr,wts)

      if(igeomtype.eq.1) then
        itype = 2
        allocate(triaskel(3,3,npatches))
        allocate(isides(npatches))
        npmax = npatches
        ntri = 0
        call xtri_platonic(itype, ipars(1), npmax, ntri, 
     1      triaskel, isides)

        xtri_geometry => xtri_sphere_eval
        ptr1 => triaskel(1,1,1)
        ptr2 => p2(1)
        ptr3 => p3(1)
        ptr4 => p4(1)


        if(ifplot.eq.1) then
           call xtri_vtk_surf(fname,npatches,xtri_geometry, ptr1,ptr2, 
     1         ptr3,ptr4, norder,'Triangulated surface of the sphere')
        endif


        call getgeominfo(npatches,xtri_geometry,ptr1,ptr2,ptr3,ptr4,
     1     npols,uvs,umatr,srcvals,srccoefs)
      endif

      if(igeomtype.eq.2) then
        done = 1
        pi = atan(done)*4
        umin = 0
        umax = 2*pi
        vmin = 0
        vmax = 2*pi
        allocate(triaskel(3,3,npatches))
        nover = 0
        call xtri_rectmesh_ani(umin,umax,vmin,vmax,ipars(1),ipars(2),
     1     nover,npatches,npatches,triaskel)

        mmax = 2
        nmax = 1
        xtri_geometry => xtri_stell_eval

        allocate(deltas(-1:mmax,-1:nmax))
        deltas(-1,-1) = 0.17d0
        deltas(0,-1) = 0
        deltas(1,-1) = 0
        deltas(2,-1) = 0

        deltas(-1,0) = 0.11d0
        deltas(0,0) = 1
        deltas(1,0) = 4.5d0
        deltas(2,0) = -0.25d0

        deltas(-1,1) = 0
        deltas(0,1) = 0.07d0
        deltas(1,1) = 0
        deltas(2,1) = -0.45d0

        ptr1 => triaskel(1,1,1)
        ptr2 => deltas(-1,-1)
        iptr3 => mmax
        iptr4 => nmax

        if(ifplot.eq.1) then
           call xtri_vtk_surf(fname,npatches,xtri_geometry, ptr1,ptr2, 
     1         iptr3,iptr4, norder,
     2         'Triangulated surface of the stellarator')
        endif

        call getgeominfo(npatches,xtri_geometry,ptr1,ptr2,iptr3,iptr4,
     1     npols,uvs,umatr,srcvals,srccoefs)
      endif
      
      return  
      end


      subroutine test_exterior_pt(npatches,norder,npts,srcvals,
     1   srccoefs,wts,xyzout,isout)
c
c
c  this subroutine tests whether the pt xyzin, is
c  in the exterior of a surface, and also estimates the error
c  in representing e^{ir/2}/r and \grad e^{ir/2}/r \cdot n
c  centered at the interior point. Whether a point 
c  is in the interior or not is tested using Gauss' 
c  identity for the flux due to a point charge
c
c
c  input:
c    npatches - integer
c       number of patches
c    norder - integer
c       order of discretization
c    npts - integer
c       total number of discretization points on the surface
c    srccoefs - real *8 (9,npts)
c       koornwinder expansion coefficients of geometry info
c    xyzout -  real *8 (3)
c       point to be tested
c
c  output: 
c    isout - boolean
c      whether the target is in the interior or not
c

      implicit none
      integer npatches,norder,npts,npols
      real *8 srccoefs(9,npts),srcvals(12,npts),xyzout(3),wts(npts)
      real *8 tmp(3)
      real *8 dpars,done,pi
      real *8, allocatable :: rsurf(:),err_p(:,:) 
      integer ipars,norderhead,nd
      complex *16, allocatable :: sigma_coefs(:,:), sigma_vals(:,:)
      complex *16 zk,val

      integer ipatch,j,i
      real *8 ra,ds
      logical isout

      done = 1
      pi = atan(done)*4

      npols = (norder+1)*(norder+2)/2


      zk = 0

      ra = 0



      do ipatch=1,npatches
        do j=1,npols
          i = (ipatch-1)*npols + j
          call h3d_sprime(xyzout,srcvals(1,i),dpars,zk,ipars,val)
          call cross_prod3d(srcvals(4,i),srcvals(7,i),tmp)
          ds = sqrt(tmp(1)**2 + tmp(2)**2 + tmp(3)**2)
          ra = ra + real(val)*wts(i)
        enddo
      enddo

      if(abs(ra+4*pi).le.1.0d-3) isout = .false.
      if(abs(ra).le.1.0d-3) isout = .true.

      return
      end

   



      subroutine l3getsph(nmax,mm,nn,ndx,xyzs,ynms,npts,ynm)
      implicit real *8 (a-h,o-z)
      real *8 :: xyzs(ndx,npts)
      complex *16 ynms(npts),ima
      real *8 rat1(10000),rat2(10000)
      real *8 ynm(0:nmax,0:nmax)
      data ima/(0.0d0,1.0d0)/
  
      call ylgndrini(nmax, rat1, rat2)
  
      do i=1,npts
        x=xyzs(1,i)
        y=xyzs(2,i)
        z=xyzs(3,i)
        r=sqrt(x**2+y**2+z**2)
        call cart2polar(xyzs(1,i),r,theta,phi)
        ctheta = cos(theta)
        call ylgndrf(nmax, ctheta, ynm, rat1, rat2)
        ynms(i) = ynm(nn,abs(mm))*exp(ima*mm*phi)        
      enddo
       
      return
      end
c
c
c
c
c
      subroutine l3getsph_vec(mm,nn,ndx,npts,xyzs,vynm,psinm,phinm)
      implicit real *8 (a-h,o-z)
      real *8 :: xyzs(ndx,npts)
      complex *16 ima
      complex *16 vynm(3,npts),psinm(3,npts),phinm(3,npts)
      real *8 vtmp(3)
      real *8, allocatable :: wlege(:),ynm(:,:),ynmd(:,:)
      complex *16 zr,zt,zp
      data ima/(0.0d0,1.0d0)/

      nmax = nn+1
  
      nlege = nmax + 10
      lw = (nlege+1)**2*4
      allocate(wlege(lw),ynm(0:nmax,0:nmax),ynmd(0:nmax,0:nmax))
      call ylgndrfwini(nlege,wlege,lw,lused)
      
  
      do i=1,npts
        x=xyzs(1,i)
        y=xyzs(2,i)
        z=xyzs(3,i)
        call cart2polar(xyzs(1,i),r,thet,phi)
        ctheta = cos(thet)
        rx = sin(thet)*cos(phi)
        ry = sin(thet)*sin(phi)
        rz = cos(thet)

        thetx = cos(thet)*cos(phi)
        thety = cos(thet)*sin(phi)
        thetz = -sin(thet)

        phix = -sin(phi)
        phiy = cos(phi)
        phiz = 0

        call ylgndr2sfw(nmax,ctheta,ynm,ynmd,wlege,nlege)

        vtmp(1) = x/r
        vtmp(2) = y/r
        vtmp(3) = z/r

        if(mm.eq.0) then
          vynm(1,i) = ynm(nn,0)*rx 
          vynm(2,i) = ynm(nn,0)*ry 
          vynm(3,i) = ynm(nn,0)*rz

          psinm(1,i) = -sin(thet)*ynmd(nn,0)*thetx
          psinm(2,i) = -sin(thet)*ynmd(nn,0)*thety
          psinm(3,i) = -sin(thet)*ynmd(nn,0)*thetz
        else
          zr = ynm(nn,abs(mm))*sin(thet)*exp(ima*mm*phi)
          vynm(1,i) = zr*rx
          vynm(2,i) = zr*ry 
          vynm(3,i) = zr*rz

          zt = -ynmd(nn,abs(mm))*exp(ima*mm*phi)
          zp = ima*mm*ynm(nn,abs(mm))*exp(ima*mm*phi)

          psinm(1,i) = zt*thetx + zp*phix
          psinm(2,i) = zt*thety + zp*phiy
          psinm(3,i) = zt*thetz + zp*phiz
        endif
        call dzcross_prod3d(vtmp,psinm(1,i),phinm(1,i))
      enddo
       
      return
      end


