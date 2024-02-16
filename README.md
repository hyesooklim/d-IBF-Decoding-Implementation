

# Simulation for "Decoding Errors in Difference-Invertible Bloom Filters: Analysis and Resolution"

This simulation is for the performance evaluation of d-IBF decoding algorithm.


## Outline
We need to generate two sets first which have a small number of different elements and the majority of elements is common. Then, we need to program two IBFs, each of which is for each set. Then, we need to perform subtract operation to build a d-IBF for two IBFs.


Upto this point, there is no difference between the conventional algorithm and the proposed algorithm.


In decoding the d-IBF, the conventional algorithm only considers sigNotEqual case and does not consider T1 cases or T2 cases, in determining whether a cell is a genuine pure cell.


On the other hand, the proposed algorithm considers sigNotEqual cases and T1 cases, and these cases are skipped without decoding because they are not genuine pure cells. 
However, since T2 cases  are not obvious before decoding, these cells are decoded. In the proposed algorithm, we can notice a T2 case occurrence when a same element is decoded twice. Hence, by invalidating both decoded elements, T2 cases are solved in our proposed algorithm.


# Caution
Resulting files are generated in the directory of "./result_conv" or "./result_prop". 
Hence, the directories with those name should be made in the current directory before starting simulation. 


# Files
- **headers**: define and set parameters (This file is very important. The numbers should be consistent with each other. Otherwise, simulation results will be wrong.)

- **LFSR**: random number generation for set generation in any length

- **CRCgenerator**: 32-bit CRC. hash index generation for IBF programming

- **TwoSetGenerator_Tb**: Set1 and Set2 are generated, and Set_Difference.txt is also generated.

- **IBFProgramming, TwoIBFProgramming_Tb**: IBF1 and IBF2 are generated for Set1 and Set2, respectively

- **d_IBF_Build, d_IBF_Build_Tb**: a d-IBF is constructed

- **d_IBF_Decoding_2, d_IBF_Decoding_Tb**: d-IBF is decoded using the proposed algorithm. IBF_left and decodedList are generated, and decoded list is compared with Set_Difference and the statistics result is stored in statistics file.


- **d_IBF_conv_decoding, d_IBF_Decoding_Conv_Tb**: d-IBF is decoded using the conventional algorithm. IBF_left and decodedList are generated, and decoded list is compared with Set_Difference and the statistics result is stored in statistics file.


# Directory
Following directories should be constructed first to store simulation results.
Otherwise, simulation will not work.


- **result_conv**
- **result_prop**


# Procedure
### 0) set headers.v 
Set Size, IBF Size, Cell Size, and accordingly index sizes should be set


### 1) TwoSetGenerator_Tb 

Sets S1, S2, Set_Difference are generated


### 2) TwoIBFProgramming_Tb
IBF1 and IBF2 are programmed


### 3) d_IBF_Build_Tb
d-IBF is constructed


### 4) d_IBF_Decoding_Tb (or d_IBF_Decoding_Conv_Tb): 
	
	
Following files are generated.
- **IBF_left** : If every distinct element is decoded, then IBF_left has all-zero entries
- **decodedList** : has decoded elements. format: {1-bit valid, x-bit element}

	- Elements with valid bit 0 are T2Case. A pair means the case is fixed. No pair means not fixed.
	- The number of decoded elements does not include the T2CaseCount if it is fixed in the proposed algorithm.


---

We found out that hash indexes generated from idSum field have the same role of sigSum field, since they can be used in differentiating one idSum from another. Hence, ther is no need to allocate a large number of bits for sigSum. 

