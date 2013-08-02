#include <iostream>

#include <cusp/ell_matrix.h>

#include "blas.h"
#include "dx.cuh"
#include "evaluation.cuh"
#include "preconditioner.cuh"
#include "typedefs.cuh"


using namespace std;
using namespace dg;

const unsigned n = 3;
const unsigned N = 40;
const double lx = 2*M_PI;

/*
double function( double x) { return sin(x);}
double derivative( double x) { return cos(x);}
*/
double function (double  x) {return x*(x-2*M_PI)*exp(x);}
double derivative( double x) { return (2.*x-2*M_PI)*exp(x) + function(x);}

int main ()
{
    cout << "Note the supraconvergence!\n";
    cout << "# of Legendre nodes " << n <<"\n";
    cout << "# of cells          " << N <<"\n";
    Grid1d<double> g( 0, lx, n, N);
    const double hx = lx/(double)N;
    cusp::ell_matrix< int, double, cusp::host_memory> hm = create::dx_asymm_mt<double>( n, N, hx, DIR);
    HVec hv = expand( function, g);
    HVec hw = hv;
    const HVec hu = expand( derivative, g);

    blas2::symv( hm, hv, hw);
    blas1::axpby( 1., hu, -1., hw);
    
    cout << "Distance to true solution: "<<sqrt(blas2::dot( S1D<double>(g), hw) )<<"\n";
    //for periodic bc | dirichlet bc
    //n = 1 -> p = 2      2
    //n = 2 -> p = 1      1
    //n = 3 -> p = 3
    //n = 4 -> p = 3      3
    //n = 5 -> p = 5      5


    
    return 0;
}