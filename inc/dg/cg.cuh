#ifndef _DG_CG_
#define _DG_CG_

#include <cmath>

#include "blas.h"

#ifdef DG_BENCHMARK
#include "timer.cuh"
#endif

namespace dg{

//// TO DO: check for better stopping criteria using condition number estimates

/**
* @brief Functor class for the preconditioned conjugate gradient method
*
 @ingroup algorithms
 @tparam Vector The Vector class: needs to model Assignable 

 The following 3 pseudo - BLAS routines need to be callable 
 \li double dot = blas1::dot( v1, v2); 
 \li blas1::axpby( alpha, x, beta, y);  
 \li blas2::symv( m, x, y);     
 \li double dot = blas2::dot( P, v); 
 \li blas2::symv( alpha, P, x, beta, y);

 @note Conjugate gradients might become unstable for positive semidefinite
 matrices arising e.g. in the discretization of the periodic laplacian
*/
template< class Vector>
class CG
{
  public:
    typedef typename VectorTraits<Vector>::value_type value_type;//!< value type of the Vector class
      /**
       * @brief Reserve memory for the pcg method
       *
       * @param copy A Vector must be copy-constructible from copy
       * @param max_iter Maximum number of iterations to be used
       */
    CG( const Vector& copy, unsigned max_iter):r(copy), p(r), ap(r), max_iter(max_iter){}
    /**
     * @brief Set the maximum number of iterations 
     *
     * @param new_max New maximum number
     */
    void set_max( unsigned new_max) {max_iter = new_max;}
    /**
     * @brief Get the current maximum number of iterations
     *
     * @return the current maximum
     */
    unsigned get_max() const {return max_iter;}
    /**
     * @brief Solve the system A*x = b using a preconditioned conjugate gradient method
     *
     @tparam Matrix The matrix class: no requirements except for the 
            BLAS routines
     @tparam Preconditioner no requirements except for the blas routines. Thus far the dg library
        provides only diagonal preconditioners, which should be enough if the result is extrapolated from
        previous timesteps.
     * In every iteration the following BLAS functions are called: \n
       symv 1x, dot 1x, axpby 2x, Prec. dot 1x, Prec. symv 1x
     * @param A A symmetric positive definit matrix
     * @param x Contains an initial value on input and the solution on output.
     * @param b The right hand side vector. x and b may be the same vector.
     * @param P The preconditioner to be used
     * @param eps The relative error to be respected
     *
     * @return Number of iterations used to achieve desired precision
     */
    template< class Matrix, class Preconditioner >
    unsigned operator()( const Matrix& A, Vector& x, const Vector& b, const Preconditioner& P , value_type eps = 1e-12);
  private:
    Vector r, p, ap; 
    unsigned max_iter;
};

/*
    compared to unpreconditioned compare
    ddot(r,r), axpby()
    to 
    ddot( r,P,r), dsymv(P)
    i.e. it will be slower, if P needs to be stored
    (but in our case P_{ii} can be computed directly
    compared to normal preconditioned compare
    ddot(r,P,r), dsymv(P)
    to
    ddot(r,z), dsymv(P), axpby(), (storage for z)
    i.e. it's surely faster if P contains no more elements than z 
    (which is the case for diagonal scaling)
    NOTE: the same comparison hold for A with the result that A contains 
    significantly more elements than z whence ddot(r,A,r) is far slower than ddot(r,z)
*/
template< class Vector>
template< class Matrix, class Preconditioner>
unsigned CG< Vector>::operator()( const Matrix& A, Vector& x, const Vector& b, const Preconditioner& P, value_type eps)
{
    value_type nrmb = sqrt( blas2::dot( P, b));
#ifdef DG_DEBUG
    std::cout << "Norm of b "<<nrmb <<"\n";
    std::cout << "Residual errors: \n";
#endif //DG_DEBUG
    if( nrmb == 0)
    {
        blas1::axpby( 1., b, 0., x);
        return 0;
    }
    //r = b; blas2::symv( -1., A, x, 1.,r); //compute r_0 
    blas2::symv( A,x,r);
    blas1::axpby( 1., b, -1., r);
    blas2::symv( P, r, p );//<-- compute p_0
    //note that dot does automatically synchronize
    value_type nrm2r_old = blas2::dot( P,r); //and store the norm of it
    value_type alpha, nrm2r_new;
    for( unsigned i=1; i<max_iter; i++)
    {
        blas2::symv( A, p, ap);
        alpha = nrm2r_old /blas1::dot( p, ap);
        blas1::axpby( alpha, p, 1.,x);
        blas1::axpby( -alpha, ap, 1., r);
        nrm2r_new = blas2::dot( P, r); 
#ifdef DG_DEBUG
        std::cout << "Absolute "<<sqrt( nrm2r_new) <<"\t ";
        std::cout << " < Critical "<<eps*nrmb + eps <<"\t ";
        std::cout << "(Relative "<<sqrt( nrm2r_new)/nrmb << ")\n";
#endif //DG_DEBUG
        if( sqrt( nrm2r_new) < eps*nrmb + eps) 
            return i;
        blas2::symv(1.,P, r, nrm2r_new/nrm2r_old, p );
        nrm2r_old=nrm2r_new;
    }
    return max_iter;
}

/**
 * @brief Function version of CG class
 *
 * @ingroup algorithms
 * @tparam Matrix Matrix type
 * @tparam Vector Vector type
 * @tparam Preconditioner Preconditioner type
 * @param A Matrix 
 * @param x contains initial guess on input and solution on output
 * @param b right hand side
 * @param P Preconditioner
 * @param eps relative error
 * @param max_iter maximum iterations allowed
 *
 * @return number of iterations
 */
template< class Matrix, class Vector, class Preconditioner>
unsigned cg( const Matrix& A, Vector& x, const Vector& b, const Preconditioner& P, typename VectorTraits<Vector>::value_type eps, unsigned max_iter)
{
    typedef typename VectorTraits<Vector>::value_type value_type;
    value_type nrmb = sqrt( blas2::dot( P, b));
#ifdef DG_DEBUG
    std::cout << "Norm of b "<<nrmb <<"\n";
    std::cout << "Residual errors: \n";
#endif //DG_DEBUG
    if( nrmb == 0)
    {
        blas1::axpby( 1., b, 0., x);
        return 0;
    }
    Vector r(x.size()), p(x.size()), ap(x.size()); //1% time at 20 iterations
    //r = b; blas2::symv( -1., A, x, 1.,r); //compute r_0 
    blas2::symv( A,x,r);
    blas1::axpby( 1., b, -1., r);
    blas2::symv( P, r, p );//<-- compute p_0
    //note that dot does automatically synchronize
    value_type nrm2r_old = blas2::dot( P,r); //and store the norm of it
    value_type alpha, nrm2r_new;
    for( unsigned i=1; i<max_iter; i++)
    {
        blas2::symv( A, p, ap);
        alpha = nrm2r_old /blas1::dot( p, ap);
        blas1::axpby( alpha, p, 1.,x);
        blas1::axpby( -alpha, ap, 1., r);
        nrm2r_new = blas2::dot( P, r); 
#ifdef DG_DEBUG
        std::cout << "Absolute "<<sqrt( nrm2r_new) <<"\t ";
        std::cout << " < Critical "<<eps*nrmb + eps <<"\t ";
        std::cout << "(Relative "<<sqrt( nrm2r_new)/nrmb << ")\n";
#endif //DG_DEBUG
        if( sqrt( nrm2r_new) < eps*nrmb + eps) 
            return i;
        blas2::symv(1.,P, r, nrm2r_new/nrm2r_old, p );
        nrm2r_old=nrm2r_new;
    }
    return max_iter;
}

/**
 * @brief Solve a symmetric linear inversion problem using a conjugate gradient method 
 *
 * @ingroup algorithms
 * Solves the Equation \f[ \hat O \phi = \rho \f]
 * for any symmetric operator O. 
 * It uses solutions from the last two calls to 
 * extrapolate a solution for the current call.
 * @tparam container The Vector class to be used
 */
template<class container>
struct Invert
{
    /**
     * @brief Constructor
     *
     * @param copyable Needed to construct the two previous solutions
     * @param max_iter maximum iteration in conjugate gradient
     * @param eps relative error in conjugate gradient
     */
    Invert(const container& copyable, unsigned max_iter, double eps): 
        eps_(eps),
        phi1( copyable.size(), 0.), phi2(phi1), cg( copyable, max_iter) { }
    /**
     * @brief Solve linear problem
     *
     * Solves the Equation \f[ \hat O \phi = W\rho \f] using a preconditioned 
     * conjugate gradient method. The initial guess comes from an extrapolation 
     * of the last solutions
     * @tparam SymmetricOp Symmetric operator with the SelfMadeMatrixTag
        The functions weights() and precond() need to be callable and return
        weights and the preconditioner for the conjugate gradient method
     * @param op selfmade symmetric Matrix operator class
     * @param phi solution (write only)
     * @param rho right-hand-side
     *
     * @return number of iterations used 
     */
    template< class SymmetricOp >
    unsigned operator()( SymmetricOp& op, container& phi, const container& rho)
    {
        return this->operator()(op, phi, rho, op.weights(), op.precond());
    }

    /**
     * @brief Solve linear problem
     *
     * Solves the Equation \f[ \hat O \phi = W\rho \f] using a preconditioned 
     * conjugate gradient method. The initial guess comes from an extrapolation 
     * of the last solutions.
     * @tparam SymmetricOp Symmetric matrix or operator (with the selfmade tag)
     * @tparam Weights class of the weights container
     * @tparam Preconditioner class of the Preconditioner
     * @param op selfmade symmetric Matrix operator class
     * @param phi solution (write only)
     * @param rho right-hand-side
     * @param w The weights that made the operator symmetric
     * @param p The preconditioner  
     *
     * @return number of iterations used 
     */
    template< class SymmetricOp, class Weights, class Preconditioner >
    unsigned operator()( SymmetricOp& op, container& phi, const container& rho, const Weights& w, const Preconditioner& p )
    {
        assert( &rho != &phi);
        blas1::axpby( 2., phi1, -1.,  phi2, phi);
        dg::blas2::symv( w, rho, phi2);
#ifdef DG_BENCHMARK
    Timer t;
    t.tic();
#endif //DG_BENCHMARK
        unsigned number = cg( op, phi, phi2, p, eps_);
#ifdef DG_BENCHMARK
    std::cout << "# of cg iterations \t"<< number << "\t";
    t.toc();
    std::cout<< "took \t"<<t.diff()<<"s\n";
#endif //DG_BENCHMARK
        phi1.swap( phi2);
        blas1::axpby( 1., phi, 0, phi1);
        return number;
    }
  private:
    double eps_;
    container phi1, phi2;
    dg::CG< container > cg;
};

} //namespace dg



#endif //_DG_CG_
