module freeze_fnc
  use pde_objs
  use typy
  use freeze_globs
  use debug_tools
  use freeze_helper
  
  public :: capacityhh, capacityhT,  diffhh, diffhT , convz
  public:: capacityTT, capacityTh, diffTT, convectTT

  
  procedure(scalar_fnc), pointer, public :: rwcap
      
      
  
  contains
    !> Capacity term due to pressure head for flow model
    !> so pde(1)
    function capacityhh(pde_loc, layer, quadpnt, x) result(val)
      use typy
      use global_objs
      use freeze_globs
      use pde_objs
    
      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return value
      real(kind=rkind)                :: val
    
      if (iceswitch(quadpnt)) then
        val = (rho_wat-rho_ice)/rho_wat*&
        rwcap(pde_loc, layer, x=(/hl(quadpnt)/))*(-log(Tref)+1)+&
        rho_ice/rho_wat*rwcap(pde_loc, layer, x=(/hl(quadpnt)/))
      else
        val = rwcap(pde_loc, layer, quadpnt)

      end if

    end function capacityhh
                 
    !> Capacity term due to temperature for flow model
    !> so pde(1)
    function capacityhT(pde_loc, layer, quadpnt, x) result(val)
      use typy
      use global_objs
      use freeze_globs
      use pde_objs
    
      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return value
      real(kind=rkind)                :: val
    
      real(kind=rkind) :: temp
    
      temp = pde(2)%getval(quadpnt)+273.15_rkind
      if (iceswitch(quadpnt)) then
        val = (rho_wat-rho_ice)/rho_wat*&
        rwcap(pde_loc, layer, x=(/hl(quadpnt)/)) * Lf/temp/grav
      else
        val = 0
      end if

    end function capacityhT

    !> diffusion due to pressure head for flow model
    !> so pde(1)
    subroutine diffhh(pde_loc, layer, quadpnt, x, tensor, scalar)
      use typy
      use global_objs
      use freeze_globs
      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return tensor
      real(kind=rkind), dimension(:,:), intent(out), optional :: tensor
      !> relative scalar value of the nonlinear function 
      real(kind=rkind), intent(out), optional                 :: scalar
      
      if (present(tensor)) then
        if(present(quadpnt)) then 
          call mualem(pde_loc, layer, x = (/hl(quadpnt)/), tensor = tensor)
          tensor = 10**(-Omega*Q_reduction(layer, quadpnt))*tensor
        end if
        if (present(x)) then
          call mualem(pde_loc, layer, x = x, tensor = tensor)
          tensor = 10**(-Omega*Q_reduction(layer, x = x))*tensor
        end if
      else
        print *, "ERROR! output tensor undefined, exited from diffhh::freeze_fnc"
      end if

    end subroutine diffhh
    
    subroutine convz(pde_loc, layer, quadpnt, x, grad,  flux, flux_length)
      use typy
      use pde_objs
      use global_objs
      use freeze_globs
       
      class(pde_str), intent(in) :: pde_loc
      integer(kind=ikind), intent(in)                          :: layer
      type(integpnt_str), intent(in), optional :: quadpnt    
      real(kind=rkind), intent(in), dimension(:), optional                   :: x
      !> this value is optional, because it is required by the vector_fnc procedure pointer global definition
      real(kind=rkind), dimension(:), intent(in), optional     :: grad
      real(kind=rkind), dimension(:), intent(out), optional    :: flux
      real(kind=rkind), intent(out), optional                  :: flux_length
      
      call dmualem_dh(pde_loc, layer, quadpnt, vector_out = flux)

    end subroutine convz
    
    !> diffusion due to temperature for flow model
    !> so pde(1)
    subroutine diffhT(pde_loc, layer, quadpnt, x, tensor, scalar)
      use typy
      use global_objs
      use freeze_globs
      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return tensor
      real(kind=rkind), dimension(:,:), intent(out), optional :: tensor
      !> relative scalar value of the nonlinear function 
      real(kind=rkind), intent(out), optional                 :: scalar
      
      real(kind=rkind), dimension(3,3) :: Klh, Klt, E
      integer(kind=ikind) :: D, i,j
      real(kind=rkind) :: temp
      
      D = drutes_config%dimen

      temp = pde(2)%getval(quadpnt)+273.15_rkind
      if (present(tensor)) then
        if (present(quadpnt)) then
          call Kliquid_temp(pde_loc, layer, quadpnt, tensor = Klt(1:D, 1:D))
          call mualem(pde_loc, layer, x=(/hl(quadpnt)/), tensor = Klh(1:D, 1:D))
          Klh(1:D,1:D) = 10**(-Omega*Q_reduction(layer, quadpnt))*Klh(1:D, 1:D)
          if(iceswitch(quadpnt)) then
            tensor = (Klt(1:D, 1:D) + Lf/temp/grav*Klh(1:D,1:D))

          else
            tensor = Klt(1:D, 1:D)
          end if
        end if
      else
         print *, "ERROR! output tensor undefined, exited from diffhT::freeze_fnc"
      end if   
      end subroutine diffhT
    
    
    !> heat: pde(2)
    !> Capacity term due to pressure head for heat flow model

    function capacityTh(pde_loc, layer, quadpnt, x) result(val)
      use typy
      use global_objs
      use freeze_globs
      use pde_objs

      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return value
      real(kind=rkind)                :: val
      
      if(.not.iceswitch(quadpnt)) then
        val = rwcap(pde_loc, layer, quadpnt)
      end if
      if(iceswitch(quadpnt)) then
        val = rwcap(pde_loc, layer, quadpnt) - (-log(Tref)+1)*rwcap(pde_loc, layer, x = (/hl(quadpnt)/))
      end if
      val = val*Lf*rho_ice
      
      val = 0
    end function capacityTh
    
    !> Capacity term due to temperature for heat flow model

    function capacityTT(pde_loc, layer, quadpnt, x) result(val)
      use typy
      use global_objs
      use freeze_globs
      use pde_objs

      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return value
      real(kind=rkind)                :: val
      
      real(kind=rkind) :: temp, vol_soil, th_air
      
      vol_soil = 1_rkind - vgset(layer)%Ths
      th_air = vgset(layer)%Ths-thetai(pde_loc, layer, quadpnt)-vangen(pde_loc, layer, x = (/hl(quadpnt)/)) 
      if(th_air < 0) then
        if(abs(th_air) > epsilon(th_air)) then
          print*, th_air
          print*, epsilon(th_air)
          print *, "the volume of air is negative"
          print *, "exited from freeze_fnc :: capacityTT"
          stop
        end if
      end if
      temp = pde(2)%getval(quadpnt)+ 273.15_rkind
      val =  Cl*rho_wat*vangen(pde_loc, layer, x = (/hl(quadpnt)/)) 
      val = val + Cs*rho_soil*vol_soil + Ca*rho_air*th_air
      if(iceswitch(quadpnt)) then
        val = (Ci*rho_ice*thetai(pde_loc, layer, quadpnt) + val &
        - Lf*rho_ice*Lf/temp/grav*rwcap(pde_loc, layer, x = (/hl(quadpnt)/)))
      end if
      
    end function capacityTT
    
    !> dispersion for heat flow model

    subroutine diffTT(pde_loc, layer, quadpnt, x, tensor, scalar)
      use typy
      use global_objs
      use freeze_globs
      class(pde_str), intent(in) :: pde_loc
      !> value of the nonlinear function
      real(kind=rkind), dimension(:), intent(in), optional    :: x
      !> Gauss quadrature point structure (element number and rank of Gauss quadrature point)
      type(integpnt_str), intent(in), optional :: quadpnt
      !> material ID
      integer(kind=ikind), intent(in) :: layer
      !> return tensor
      real(kind=rkind), dimension(:,:), intent(out), optional :: tensor
      !> relative scalar value of the nonlinear function 
      real(kind=rkind), intent(out), optional                 :: scalar
      
      integer(kind=ikind) :: D, i
      
     
      D = drutes_config%dimen

      
      if (present(tensor)) then
        do i= 1, D
          tensor(i,i) =  thermal_cond
        end do
      end if
      
      
    end subroutine diffTT
    
    
    subroutine convectTT(pde_loc, layer, quadpnt, x, grad,  flux, flux_length)
      use typy
      use pde_objs
      use global_objs
      use freeze_globs
       
      class(pde_str), intent(in) :: pde_loc
      integer(kind=ikind), intent(in)                          :: layer
      type(integpnt_str), intent(in), optional :: quadpnt    
      real(kind=rkind), intent(in), dimension(:), optional                   :: x
      !> this value is optional, because it is required by the vector_fnc procedure pointer global definition
      real(kind=rkind), dimension(:), intent(in), optional     :: grad
      real(kind=rkind), dimension(:), intent(out), optional    :: flux
      real(kind=rkind), intent(out), optional                  :: flux_length
      
      
      if (present(flux)) then
          call all_fluxes(pde_loc, layer, quadpnt,  flux = flux)
          flux = Cl *rho_wat*flux
          flux = 0
        end if
        
        if (present(flux_length)) then
           call all_fluxes(pde_loc, layer, quadpnt, flux_length = flux_length)
           flux_length = Cl *rho_wat*flux_length
           flux_length = 0
        end if
              
    end subroutine convectTT
    
    subroutine all_fluxes(pde_loc, layer, quadpnt, x, grad,  flux, flux_length)
      use typy
      use pde_objs
      use global_objs
       
      class(pde_str), intent(in) :: pde_loc
      integer(kind=ikind), intent(in)                          :: layer
      type(integpnt_str), intent(in), optional :: quadpnt    
      real(kind=rkind), intent(in), dimension(:), optional                   :: x
      !> this value is optional, because it is required by the vector_fnc procedure pointer global definition
      real(kind=rkind), dimension(:), intent(in), optional     :: grad
      real(kind=rkind), dimension(:), intent(out), optional    :: flux
      real(kind=rkind), intent(out), optional                  :: flux_length

      real(kind=rkind), dimension(3,3)  :: Klh, Klt
      integer                           :: D
      !integer(kind=ikind), dimension(3) :: nablaz
      real(kind=rkind), dimension(3)  :: gradH
      real(kind=rkind), dimension(3)  :: vct
      real(kind=rkind) :: h
      real(kind=rkind), dimension(:), allocatable :: gradient, gradientT
      type(integpnt_str) :: quadpnt_loc
      

      
      if (present(quadpnt) .and. (present(grad) .or. present(x))) then
        print *, "ERROR: the function can be called either with integ point or x value definition and gradient, not both of them"
        ERROR stop
      else if ((.not. present(grad) .or. .not. present(x)) .and. .not. present(quadpnt)) then
        print *, "ERROR: you have not specified either integ point or x value"
        print *, "exited from freeze_fnc::all_fluxes"
        ERROR stop
      end if
      
      if (present(quadpnt)) then
        quadpnt_loc = quadpnt
        quadpnt_loc%preproc=.true.
        h = hl(quadpnt)
        call pde_loc%getgrad(quadpnt, gradient)
        call pde(2)%getgrad(quadpnt, gradientT)
      else
        if (ubound(x,1) /=1) then
          print *, "ERROR: van Genuchten function is a function of a single variable h"
          print *, "       your input data has:", ubound(x,1), "variables"
          print *, "exited from freeze_fnc::all_fluxes"
          ERROR STOP
        end if
        h = x(1)
        allocate(gradient(ubound(grad,1)))
        gradient = grad
      end if
      
      D = drutes_config%dimen

      !nablaz = 0
      !nablaz(D) = 1
      
      gradH(1:D) = gradient(1:D) !+ nablaz(1:D)
      if(present(quadpnt)) then
        call pde_loc%pde_fnc(1)%dispersion(pde_loc, layer, x=(/hl(quadpnt)/), tensor=Klh(1:D, 1:D))
        Klh(1:D,1:D) = 10**(-Omega*Q_reduction(layer, quadpnt))*Klh(1:D, 1:D)
        call pde_loc%pde_fnc(2)%dispersion(pde_loc, layer, quadpnt, tensor = Klt(1:D, 1:D))

      else if (present(x)) then
        call pde_loc%pde_fnc(1)%dispersion(pde_loc, layer, x = x, tensor=Klh(1:D, 1:D))
        Klh(1:D,1:D) = 10**(-Omega*Q_reduction(layer, x = x))*Klh(1:D, 1:D)
      end if
      vct(1:D) = matmul(-Klh(1:D,1:D), gradH(1:D))+matmul(-Klt(1:D,1:D), gradientT(1:D))


      if (present(flux_length)) then
        select case(D)
          case(1)
                flux_length = vct(1)
          case(2)
                flux_length = sqrt(vct(1)*vct(1) + vct(2)*vct(2))
          case(3)
                flux_length = sqrt(vct(1)*vct(1) + vct(2)*vct(2) + vct(3)*vct(3))
        end select
      end if


      if (present(flux)) then
        flux(1:D) = vct(1:D)
      end if

    end subroutine all_fluxes
    
end module freeze_fnc
