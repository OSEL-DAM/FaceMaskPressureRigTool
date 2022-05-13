# FaceMaskPressureRigTool

This code and setup was published as supporting information for **_A modified method for measuring pressure drop in non-medical face masks with automated data acquisition and analysis_** by Herman et al. in the [Journal of the International Society of Respirtory Protection](https://www.isrp.com/the-isrp-journal/complete-journal-archive-for-members-only/1255-vol-38-no-2-2021/file#page=16) (_ISRP Membership Required to View_) in December of 2021.

An open access verison is also published in PubMed under the following ID: #######

## Disclaimer

* This respository's contents are under a CC0 v1.0 Universal Licence.  However, this license does not govern the software needed to run or open the files in this repository and may be governed under a sperate license.
* The use of the files in this repository, the code presented in it, its dependent functions, or the software required to run it does not constitute an endorsement from the U.S. Food and Drug Administration or U.S. Department of Health and Human Services.

## Introduction

This repository can be broken down into 3 parts:

1. Pressure Plate STL
2. Data Aquisition Python Script
3. Data Processing MATLAB Script and Dependent Functions

## Pressure Plate STL

An STL file of pressure drop rig that we used in the manuscript. Units are in millimeters. Two prints of this STL are required for the full pressure rig. One half can optionally be mirrored on the ring side to have all of the ports on the same side. The gasket shape can be created by converting to a vector file of the ring side. The two halfs and the gaskets, along with the sample under test, can be held together with 4x M3 x 0.5mm, 60mm long screws.

The main inlet and outlet ports are designed for 1/8" NPT fittings that can be RTVed or expoxied in.

The pressure ports designed for 1/4"-28 thread fittings that can be RTVed or expoxied in.

## Data Aquisition Python Script

This python  script (`presslog.py`) is a CLI based script that requires:
* A Raspberry Pi
* An ADS1115 16-bit ADC and its required libraries (See Below)
* A pressure transducer module with a linear output voltage of 0 to 5 Volts (and an impedence which is compatible with the ADS1115)
	
Obtain help in running the script by typing: 

`python3 presslog.py -h`
	
Run the script by typing:

`python3 presslog.py`
	
### Helpful Links

[How to install CircuitPython Libraries from Adafruit](https://learn.adafruit.com/circuitpython-on-raspberrypi-linux/installing-circuitpython-on-raspberry-pi)
		
[Python Command Line Areguments Help](https://www.tutorialspoint.com/python/python_command_line_arguments.htm)
		
## Data Processing MATLAB Script and Dependent Functions

The output of the `presslog.py` script will output a CSV file that can be analyzed by the MATLAB script `pAnalysis.m`[^1]. `pAnalysis.m` can handle multiple CSVs output from `presslog.py`. All CSVs, `pAnalysis.m` and all  All of the required files are in the pAnalysis directory. The scripts and functions required for processing are as follows:

* `pAnalysis.m` - Script for Importing and Processing the CSVs outputed from `presslog.py`
* `pDataImport.m` - Function that Imports a specified CSV to the MATLAB workspace
* `newMaterial.m` - Lookup table helper function to standarize material names
* `pSpike.m` - Function to detect a sudden spike in pressure
* `pCell2CSV.m` - Function to output a MATLAB cell contents to a CSV file

### pAnalysis.m

`PAnalysis.m` is a script that import pressure logging files outputted from our pressure transducer setup. This Script imports a pressure transducer log file and calculates the average pressure after the index the script finds when the flow controller was turned on plus an offset. This is repeated for every log file in the same directory and a report can be generated.

This script is designed to read pressure data from two differential pressure transducers of different sensitivities. It averages the pressures from both transducers and only selects the reading from the transducer that is the most sensitive where it does not clip. This code can be used for any pressure unit specified (Quantity of Interest [QOI]). This script can also be used with one transducer

**Requires:** MATLAB R2006a (Tested with R2020b & R2014b) 

*NOTE:* The functions used in this code are compatible with versions R2006a or before. However some input parameters and Name/Value pairs might not be compatible. Make sure function inputs used here and with supplied functions are compatible with the version of MATLAB being used to run this script.

***IMPORTANT:*** For the grouping of materials to happen properly, the nomenclature of the pressure files name must be the following format:

    !Press#<material>#yyyy_mm_dd_HH-MM-SS.csv

This format is based on the output of `presslog.py` and the script is designed around it. 
   
   `!Press` at the start of the file name identifies if this a pressure  logging file. Any files that does not have this tag and not have an extention of TXT is not loaded for analysis.

  `\<material\>` is the user entered material from the `presslog.py` and must be sperated pound signs (#) at the start and end of the material. There is a validation of the material in the file name and the material name in the file. If there is a discrepancy, a warning is displayed.

  After the material is a time stamp of when then the analysis started. It must be in the format listed above as there is a validation of the time stamp in the name and the time stamp in the file. If there is a discrepancy, a warning is displayed.

*NOTE:* Only one Flow Rate Can Summarized at a time. Code assumes all Pressure Logging files and cataloged under the same flow rate. This only affects the output of `p_report` (Variable in `pAnalysis.m`) and the saved CSV

### pDataImport.m

`pDataImport.m` is a function that imports data from a text file outputted from our pressure transducer logger program. It reads data from text file name (`filename`) passed to it and output the data from the file in a structure. This fuction is based on the text file output from `presslog.py` and reads all of the different data fields from that text file.

| Input Parameter | Description |
| :---: | :--- |
| `filename` | char array of a CSV file name to import |

###  newMaterial.m

`newMaterial.m` is a function that compares the material name (`oldname`) passed to the function against a lookup table (`oldnewnames`) and either returned the standardized name from the table in the form of a Nx2 cell array with charater vectors or returns the old name based off a input flag (`std_name`).

**Lookup Table Format (oldnewnames)**
| Column 1 | Column 2 |
| :---: | :---: |
| Old Name | New to Replace Old Name in Corresponding Row |


A standardized name will be returned if `std_name` is true and there is a match of the `oldname` in column 1 in `oldnewnames`. The standardized name will be in column 2 of the same row where the `oldname` is found in column 1 of `oldnewnames`. If no match if found or `std_name` flag is false then the `oldname` is returned.

| Input Parameter | Description |
| :---: | :--- |
| `oldname` | Material Name to compare to the lookup table (`oldnewnames`) |
| `std_name` | Flag to return a Standard Name or Return the old one |

### pSpike.m

`pSpike.m` is a function that detects a sudden change in a 1D vector signal (Pressure) and outputs its index. This is done by picking a random point along the vector finding the cumulative variances on both side of the point, multiplying it by the index of the random point from each end, adding them together. The point with the smallest sum represents the point where the variances on both sides are least fluctuating and thus results in the most significant point where the signal changes.

| Input Parameter | Description |
| :---: | :--- |
| `P_data` | Pressure data vector  |

#### pSpike.m References

1.	"Find abrupt changes in signal - MATLAB findchangepts", Mathworks.com, 2016. [Online]. Available: https://www.mathworks.com/help/signal/ref/findchangepts.html#d123e60404. [Accessed: 04-Jun-2021]

2.	P. P. Pebay, "Formulas for robust, one-pass parallel computation of covariances and arbitrary-order statistical moments,"; Sandia National Laboratories (SNL), Albuquerque, NM, and Livermore, CA (United States), SAND2008-6212; TRN: US201201%%57 United States 10.2172/1028931 TRN: US201201%%57 SNL English, 2008. [Online]. Available: https://www.osti.gov/servlets/purl/1028931

3.  T. F. Chan, G. H. Golub, and R. J. LeVeque, "Algorithms for Computing the Sample Variance: Analysis and Recommendations," The American Statistician, vol. 37, no. 3, pp. 242-247, 1983, doi:10.2307/2683386.

4.	R. Killick, P. Fearnhead, and I. A. Eckley, "Optimal Detection of Changepoints With a Linear Computational Cost," Journal of the American Statistical Association, vol. 107, no. 500, pp. 1590-1598, 2012. [Online]. Available: http://www.jstor.org/stable/23427357.

5.	J. Muñoz and C. Luengo, "Which function allow me to calculate cumulative variance over a vector?", Stack Overflow, 2019. [Online]. Available: https://stackoverflow.com/questions/58343348/. [Accessed: 04-Jun-2021].

### pCell2CSV.m

`pCell2CSV.m` is a function that saves a cell array to a CSV file. This function uses `fprintf` to output a CSV file. This was used to over the newer `writecell` for compatibility with older versions of MATLAB.


| Input Parameter | Description |
| :---: | :--- |
| `pCell_in` | Cell Array to be saved as a CSV File |
| `FN` | Character array of the file name of the CSV to be outputted less the file extention |
| `num_per` | Precision of the number to output in the output table |


[^1]: Assuming the proceedure outlined in the manuscript is followed.