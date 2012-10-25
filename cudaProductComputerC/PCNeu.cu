// PCNeu.cpp : Definiert den Einstiegspunkt f�r die Konsolenanwendung.
//

#include "Definitions.h"
#include "SignedBlade.h"
#include "GAMethods.h"
#include <iostream>

#include "BladelistCreator.h"

#include "InnerProductComputing.h"
#include "OuterGeoProductComputing.h"
#include "Grouper.h"
#include "Outputter.h"

#include <boost/unordered_map.hpp>

#include <time.h>
#include <fstream>

#include "BitWriter.h"
#include "BitReader.h"

// CUDA runtime
#include <cuda_runtime.h>



#define COMPUTE_INNER_PRODUCT
#define COMPUTE_OUTER_AND_GEO_PRODUCT

#define PRINT_TO_FILE

void printBladelist(Bladelist& list, void (*printer) (Blade&, std::ostream&)) {
	std::fstream out("D:\\blades.csv",std::fstream::out);
	int index = 0;
	for (Bladelist::iterator sblade1=list.begin(); sblade1 != list.end(); ++sblade1) {
		SumOfBlades&s = *sblade1;
		out << index << ": ";
		output(s,printer,out);
		out << std::endl;
		index++;
	}
	out.close();
}

#include "CalcThread.h"

#include <helper_functions.h>


#define BLADECOUNT 32

 __global__ void simpleCopyKernel(int* in_pos, int* out_pos) {
	int tx = threadIdx.x;
	out_pos[tx] = in_pos[tx]*2;
}

void cudaCalculateProducts(SumOfBlades* pmTransformedZI) {
	// == allocate memories ==
	
	// retrieve informations about positions, lenghts and number of elements
	int positionsPMTransformedZI[BLADECOUNT];
	int lengthsPMTransformedZI[BLADECOUNT];
	int summandCountPMTransformedZI = 0;
	int position = 0;
	for (int i=0;i<BLADECOUNT;i++) {
		positionsPMTransformedZI[i] = position;
		lengthsPMTransformedZI[i] = pmTransformedZI[i].size();
		summandCountPMTransformedZI += lengthsPMTransformedZI[i];
		position += lengthsPMTransformedZI[i];
	}

	float* coefficentsPMTransformedZI = new float[summandCountPMTransformedZI];
	int index = 0;
	for (int i=0;i<BLADECOUNT;i++) 
		for (SumOfBlades::iterator sblade1 = pmTransformedZI[i].begin(); sblade1 != pmTransformedZI[i].end(); ++sblade1) {
			coefficentsPMTransformedZI[index] = (*sblade1).coefficient;
			index++;
		}

	// allocate memory pmTransformedZI
	float* cin_coefficentsPMTransformedZI;
	int size = summandCountPMTransformedZI * sizeof(float);
	cudaMalloc((void**) &cin_coefficentsPMTransformedZI, size);
	cudaMemcpy(cin_coefficentsPMTransformedZI, coefficentsPMTransformedZI, size, cudaMemcpyHostToDevice);

	int* cin_positionsPMTransformedZI;
	cudaMalloc((void**) &cin_positionsPMTransformedZI, BLADECOUNT*sizeof(int));
	cudaMemcpy(cin_positionsPMTransformedZI, positionsPMTransformedZI, size, cudaMemcpyHostToDevice);

	int* cin_lengthsPMTransformedZI;
	cudaMalloc((void**) &cin_lengthsPMTransformedZI, BLADECOUNT*sizeof(int));
	cudaMemcpy(cin_lengthsPMTransformedZI, lengthsPMTransformedZI, size, cudaMemcpyHostToDevice);

	// allocate memory for output
	//TODO first some testing
	int* cout_out;
	cudaMalloc((void**) &cout_out, BLADECOUNT*sizeof(int));
	cudaMemset(cout_out,0,BLADECOUNT*sizeof(int));

	// TODO CPU: collect results on host-memory, print it, or store it into a binary file for loading in Gaalop
	dim3 dimBlock(1,1,1);
	dim3 dimGrid(BLADECOUNT,1,1);
	simpleCopyKernel<<<dimGrid,dimBlock>>>(cin_positionsPMTransformedZI, cout_out);


	// retrieve data from gpu global memory
	int out[BLADECOUNT];

	cudaMemcpy(out, cout_out, BLADECOUNT*sizeof(int), cudaMemcpyDeviceToHost);

	for (int i = 0;i<BLADECOUNT;i++) 
		std::cout << out[i] << std::endl;

	// Free memory
	cudaFree(cout_out);
	cudaFree(cin_coefficentsPMTransformedZI);
	cudaFree(cin_positionsPMTransformedZI);
	cudaFree(cin_lengthsPMTransformedZI);
}


/**
	Creates the producttables of a geometric algebra using CUDA.
 **/
int main3(int argc, char* argv[])
{
	time_t start;
	time(&start);

	// CPU: create bladeListZI
	Bladelist bladelistZI;
	initializeBladelist(bladelistZI);
	
	// CPU: transform bladeListZI into Sum-Of-PMBlades variable pmTransformedZI
	SumOfBlades pmTransformedZI[BLADECOUNT];
	for (int index=0;index<BLADECOUNT;index++) {
		SumOfBlades b;
		b.push_back(SignedBlade(Blade(index)));
		SumOfBlades& pm = pmTransformedZI[index];
		basetransformationZeroInfToPlusMinus(b, pm);
		group(pm);
	}
	
	// CPU: create transformations from PM to ZI 
	SumOfBlades ziTransformedPM[BLADECOUNT];
	for (int index=0;index<BLADECOUNT;index++) {
		SumOfBlades b;
		b.push_back(SignedBlade(Blade(index)));
		SumOfBlades& zi = ziTransformedPM[index];
		basetransformationPlusMinusToZeroInf(b,zi);
		group(zi);
	}

	// TODO CUDA: calculate all products in PM, transform it into ZI, store it on host-memory
	cudaCalculateProducts(pmTransformedZI);
	

	time_t ende;
	time(&ende);
	std::cout << "Ready in " << difftime(ende, start) << " seconds" << std::endl;
	getchar();
	return 0;
}


/*
//int maxNumber = 0; //TODO
	//std::cout << "MaxNumber = " << maxNumber <<std::endl;
// komprimieren
	int number = 2;
    int bitCount2 = 1;
    while (number < maxNumber+1) {
        bitCount2++;
        number *= 2;
    }
	*/