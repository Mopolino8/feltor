#ifndef _DG_EVALUATION_
#define _DG_EVALUATION_

#include <cassert> 
#include "grid.cuh"
#include "matrix_traits_thrust.h"
#include "operator_dynamic.h"

//#include "arrvec1d.cuh"
//#include "arrvec2d.cuh"
//#include "dlt.h"

/*! @file function discretization routines
  */
namespace dg
{


///@addtogroup evaluation
///@{



/**
 * @brief Evaluate a function on gaussian abscissas
 *
 * Evaluates f(x) on the intervall (a,b)
 * @tparam Function Model of Unary Function
 * @param f The function to evaluate
 * @param g The grid on which to evaluate f
 *
 * @return  A DG Host Vector with values
 */
template< class Function>
thrust::host_vector<double> evaluate( Function f, const Grid1d<double>& g)
{
    thrust::host_vector<double> abs = create::abscissas( g);
    for( unsigned i=0; i<g.size(); i++)
        abs[i] = f( abs[i]);
    return abs;
};
///@cond
thrust::host_vector<double> evaluate( double (f)(double), const Grid1d<double>& g)
{
    thrust::host_vector<double> v = evaluate<double (double)>( f, g);
    return v;
};
///@endcond


/**
 * @brief Evaluate a function on gaussian abscissas
 *
 * Evaluates f(x) on the given grid
 * @tparam Function Model of Binary Function
 * @param f The function to evaluate: f = f(x,y)
 * @param g The 2d grid on which to evaluate f
 *
 * @return  A DG Host Vector with values
 * @note Copies the binary Operator. This function is meant for small function objects, that
            may be constructed during function call.
 */
template< class BinaryOp>
thrust::host_vector<double> evaluate( BinaryOp f, const Grid<double>& g)
{
    unsigned n= g.n();
    //TODO: opens dlt.dat twice...!!
    Grid1d<double> gx( g.x0(), g.x1(), n, g.Nx()); 
    Grid1d<double> gy( g.y0(), g.y1(), n, g.Ny());
    thrust::host_vector<double> absx = create::abscissas( gx);
    thrust::host_vector<double> absy = create::abscissas( gy);

    thrust::host_vector<double> v( g.size());
    for( unsigned i=0; i<gy.N(); i++)
        for( unsigned j=0; j<gx.N(); j++)
            for( unsigned k=0; k<n; k++)
                for( unsigned l=0; l<n; l++)
                    v[ i*g.Nx()*n*n + j*n*n + k*n + l] = f( absx[j*n+l], absy[i*n+k]);
    return v;
};
///@cond
thrust::host_vector<double> evaluate( double(f)(double, double), const Grid<double>& g)
{
    //return evaluate<double(&)(double, double), n>( f, g );
    return evaluate<double(double, double)>( f, g);
};
///@endcond



/**
 * @brief Evaluate and dlt transform a function 
 *
 * Evaluates f(x) on the given grid
 * @tparam Function Model of Unary Function
 * @param f The function to evaluate: f = f(x)
 * @param g The grid on which to evaluate f
 *
 * @return  A DG Host Vector with dlt transformed values
 */
template< class Function>
thrust::host_vector<double> expand( Function f, const Grid1d<double>& g)
{
    thrust::host_vector<double> v = evaluate( f, g);
    Operator<double> forward( g.dlt().forward());
    double temp[g.n()];
    for( unsigned k=0; k<g.N(); k++)
    {
        for(unsigned i=0; i<g.n(); i++)
        {
            temp[i] = 0;
            for( unsigned j=0; j<g.n(); j++)
                temp[i] += forward(i,j)*v[k*g.n()+j];
        }
        for( unsigned j=0; j<g.n(); j++)
            v[k*g.n()+j] = temp[j];
    }
    return v;
};
///@cond
thrust::host_vector<double> expand( double(f)(double), const Grid1d<double>& g)
{
    return expand<double(double)>( f, g);
};

///@endcond




/**
 * @brief Evaluate and dlt transform a function
 *
 * Evaluates and dlt-transforms f(x) on the given grid
 * @tparam Function Model of Binary Function
 * @param f The function to evaluate: f = f(x,y)
 * @param g The 2d grid on which to evaluate f
 *
 * @return  A DG Host Vector with values
 * @note Copies the binary Operator. This function is meant for small function objects.
 */
template< class BinaryOp>
thrust::host_vector<double> expand( BinaryOp f, const Grid<double>& g)
{
    thrust::host_vector<double> v = evaluate( f, g);
    unsigned n = g.n();
    Operator<double> forward( g.dlt().forward());
    double temp[n][n];
    //DLT each dg-Box 
    for( unsigned i=0; i<g.Ny(); i++)
        for( unsigned j=0; j<g.Nx(); j++)
        {
            //first transform each row
            for( unsigned k=0; k<n; k++) 
                for( unsigned l=0; l<n; l++)
                {
                    //multiply forward-matrix with each row k
                    temp[k][l] = 0;
                    for(  unsigned ll=0; ll<n; ll++)
                        temp[k][l] += forward(l,ll)*v[ i*n*n*g.Nx() + j*n*n + k*n + ll];
                }
            //then transform each col
            for( unsigned k=0; k<n; k++) 
                for( unsigned l=0; l<n; l++)
                {
                    //multiply forward-matrix with each col 
                    v[i*n*n*g.Nx() + j*n*n + k*n + l] = 0;
                    for(  unsigned kk=0; kk<n; kk++)
                        v[i*n*n*g.Nx() + j*n*n + k*n + l] += forward(k,kk)*temp[kk][l];
                }
        }

    return v;
};

///@cond
thrust::host_vector<double> expand( double(f)(double, double), const Grid<double>& g)
{
    return expand<double(double, double)>( f, g);
};

///@endcond


///@}
}//namespace dg

#endif //_DG_EVALUATION