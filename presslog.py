#Raspberry Pi Pressure Logging Program, V1.0
#presslog.py
#by Daniel Porter
#2021_04_19
"""
This python script requires:
	-A Raspberry Pi
	-An ADS1115 16-bit ADC
	-A pressure transducer module with a linear output voltage of 0 to 5 Volts (and an impedence which is compatible with the ADS1115)
	
	Obtain help in running the script by typing "python3 presslog.py -h"
	Run the script by typing "python3 presslog.py"
	
	How to install CircuitPython from Adafruit
	https://learn.adafruit.com/circuitpython-on-raspberrypi-linux/installing-circuitpython-on-raspberry-pi
		
	Additional resources:
	https://www.tutorialspoint.com/python/python_command_line_arguments.htm
		
"""

import sys, getopt, select, os, tty, termios, os.path 	#Some imports which are needed
import time 											#Needed for time operations
from datetime import datetime							#Used to grab the date and time

import board 											#Needed for Raspberry Pi pin operations
import busio 											#Needed for Raspberry Pi i2c

import adafruit_ads1x15.ads1115 as ADS 					#Import the ADS1115 library  
from adafruit_ads1x15.ads1x15 import Mode
from adafruit_ads1x15.analog_in import AnalogIn 		#Import the ADC library  

old_settings = termios.tcgetattr(sys.stdin) #used to restore keyboard settings
def clear(): os.system('clear') #Clear screen on Linux System

i2c = busio.I2C(board.SCL, board.SDA) #define our i2c line
ads = ADS.ADS1115(i2c) #define the ads board which is our ADC
ads.gain = 2/3 #Set the ADS1115 gain to its highest value

#Initialize global variables
outputfile = "default" #Variable to hold file name

numADCchan = 4 #Number of ADC channels
numADCrange = 8 #Number of ADC samples used to calculate the ranges
numADCaverage = 8 #Number of ADC samples used to calculate the averages

voltage = [0]*numADCchan #Voltage array 
vMulti = [0]*numADCchan #Voltage to qoi linear multiplier in units/V
qoiOffSet = [0]*numADCchan #qoi Offset
qoi = [0]*numADCchan #qoi values
qUnits = [0]*numADCchan #qoi units

#Variables for Averaging and Range
voltageRNGcnt = 0 ##Counter which keeps track of current sample to range
voltageAVGcnt = 0 #Counter which keeps track of current sample to average
voltageRNG = [[0]*numADCrange for i in range(numADCchan)] #Holds the samples to calculate the ranges
voltageAVG = [[0]*numADCaverage for i in range(numADCchan)] #Holds the samples to calculate the averages
voltageRNGval = [0]*numADCchan #Holds the range value for the channels
voltageAVGval = [0]*numADCchan #Holds the average value for the channels
qoiRNGval = [0]*numADCchan #Holds the range value for the channels
qoiAVGval = [0]*numADCchan #Holds the range value for the channels

SampleFreq = 10 #Frequency to sample the ADC
SampleDTime = 1.0/SampleFreq #calculate the delta time needed for the loop
SampleNumber = 0 #Counts the ADC samples taken
CurrentTime = time.time() - time.time() #Holds the current time of the DAQ program

RecordData = 0 #Variable to start logging data
HeaderWritten = 0 #Variable that tell program the header is written

notes = "" #Global variable that is used to display the last operation or current function for the program
strProgramHeader = "Running: presslog.py\tVersion 20210419\tBy Daniel Porter" #Header which is displayed at the top of the program

def main(argv):
   
	global outputfile
	global notes
	global RecordData
	global SampleFreq
	global SampleDTime
	global HeaderWritten
	global SampleNumber
	global CurrentTime
	
	Init() #Initialize global variables if not already done so
	
	#Define local variables
	file1 = 0 #variable that holds the file reference
		
	StartTime = time.time() #Grab the current system time in seconds
	DispUpdateTime = 0.5 #How many seconds to pass before updating display
		
	#Process script input arguments
	#https://docs.python.org/3/library/getopt.html
	try:
		opts, args = getopt.getopt(argv,"f:ho:",["ofile=","freq=","multi0=","multi1=","multi2=","multi3=","offset0=","offset1=","offset2=","offset3=","units0=","units1=","units2=","units3="])
	except getopt.GetoptError: #if there is an error, then display valid arguments for script and exit script
		print('presslog.py -o <outputfile> -f <sampling frequency> --multi<chn>=<volt-QOI conversion in Units/V> --offset<chn>=<QOI offset> --units<chn>=<QOI units>')
		print('Example: We want to log pressure with the ADS1115 to a file MyPressureData.txt at 10 Hz,  ')
		print('Example: with a channel 0 multiplier, offset, and units of 1.530 mmH20/V, 0.256 mmH20, and mmH20,')
		print('Example: with a channel 2 multiplier, offset, and units of 3.800 PSI/V, 1.300 PSI, and PSI,')
		print('Example: python3 presslog.py -o MyPressureData -f 10 --multi0=1.530 --offset0=0.256 --units0=mmH20 --multi2=3.800 --offset2=1.300 --units2=PSI')
		sys.exit(2)
	for opt, arg in opts:
		if opt == '-h': #If help argument is received
			print('presslog.py -o <outputfile> -f <sampling frequency> --multi<chn>=<volt-QOI conversion in Units/V> --offset<chn>=<QOI offset> --units<chn>=<QOI units>')
			print('Example: We want to log pressure with the ADS1115 to a file MyPressureData.txt at 10 Hz,  ')
			print('Example: with a channel 0 multiplier, offset, and units of 1.530 mmH20/V, 0.256 mmH20, and mmH20,')
			print('Example: with a channel 2 multiplier, offset, and units of 3.800 PSI/V, 1.300 PSI, and PSI,')
			print('Example: python3 presslog.py -o MyPressureData -f 10 --multi0=1.530 --offset0=0.256 --units0=mmH20 --multi2=3.800 --offset2=1.300 --units2=PSI')
			sys.exit()
		elif opt in ("-o", "--ofile"):
			outputfile = arg
		elif opt in ("-f", "--freq"):
			SampleFreq = float(arg)
		elif opt in ("--multi0"):
			vMulti[0] = float(arg)
		elif opt in ("--multi1"):
			vMulti[1] = float(arg)
		elif opt in ("--multi2"):
			vMulti[2] = float(arg)
		elif opt in ("--multi3"):
			vMulti[3] = float(arg)
		elif opt in ("--offset0"):
			qoiOffSet[0] = float(arg)
		elif opt in ("--offset1"):
			qoiOffSet[1] = float(arg)
		elif opt in ("--offset2"):
			qoiOffSet[2] = float(arg)
		elif opt in ("--offset3"):
			qoiOffSet[3] = float(arg)
		elif opt in ("--units0"):
			qUnits[0] = arg
		elif opt in ("--units1"):
			qUnits[1] = arg
		elif opt in ("--units2"):
			qUnits[2] = arg
		elif opt in ("--units3"):
			qUnits[3] = arg
   
	#Recalculate and initialize variables needed from input arguments
	SampleDTime = 1.0/SampleFreq #calculate the delta time needed for the loop
	CurrentTime = time.time()-StartTime #Calculate current time
	DispLastTime = CurrentTime #Update the display time
	CaptLastTime = CurrentTime #Elapsed time for the data capture  
	
	#Now run the main loop
	while True: #Keep sampling, writing to console, and writing to file until the user presses something on the keyboard
		try:
			tty.setcbreak(sys.stdin.fileno()) #Turn off echo for keyboard, turn off cooked mode					
			CurrentTime = time.time()-StartTime #Calculate current time
								
			#Update output to console.  Updating every 0.5 second per the initial variables.
			if ( (CurrentTime-DispLastTime) > DispUpdateTime):
				clear()
				PrintScreen()
				DispLastTime = CurrentTime #update the last display time
						
			#Capture and Write data to file
			if ( (CurrentTime-CaptLastTime) > SampleDTime):
				RecordAndProcessADC() #Grab processed data, store in variables
				SampleNumber +=1 #Update sample taken
							
				if (RecordData):
					WriteDataToFile(file1, SampleNumber, CurrentTime)

				CaptLastTime = CurrentTime #update the last display time
			
			#This section is used to detect keyboard input, then operate on it
			if isData():
				c = sys.stdin.read(1)
				#print("Pressed the key: "+c)
				if c == chr(10):         # chr(10) is the enter key, #This section is used to stop the logging if the user presses "Enter".
					ExitProgram(file1)
				elif c == '0': #zero the 0 channel
					qoiOffSet[0] = qoiOffSet[0] - qoi[0]
					notes = "Channel 0 zero'd, qoiOffSet[0]=" + str(qoiOffSet[0])
				elif c == '1': #zero the 1 channel
					qoiOffSet[1] = qoiOffSet[1] - qoi[1]
					notes = "Channel 1 zero'd, qoiOffSet[1]=" + str(qoiOffSet[1])
				elif c == '2': #zero the 2 channel
					qoiOffSet[2] = qoiOffSet[2] - qoi[2]
					notes = "Channel 2 zero'd, qoiOffSet[2]=" + str(qoiOffSet[2])
				elif c == '3': #zero the 3 channel
					qoiOffSet[3] = qoiOffSet[3] - qoi[3]
					notes = "Channel 3 zero'd, qoiOffSet[3]==" + str(qoiOffSet[3])
				elif c == 'c': #stop recording and close file
					if (RecordData == 1): #only do this once
						if(file1.closed==False): #if the file is open, close it
							file1.close()
						RecordData = 0 #reset data recording variable
						HeaderWritten = 0 #Reset header writing boolean
						notes = "File " + filename + " closed at " + now.strftime("%Y_%m_%d_%H-%M-%S") 
						#print("File closed")
				elif c == chr(32): #Space: Create new file, open it and set boolean variable to write header and record the data
					if (RecordData == 0): #only do this once
						try: #Open the file if it does not already exist 
							now = datetime.now() #get the current date and time
							filename = os.path.splitext(outputfile)[0] + now.strftime("_%Y_%m_%d_%H-%M-%S") + ".txt" #Grab the name of the file iput and strip off the extension.  Append date and time.
							notes = "Recording to file "+filename
							#print("Opening file "+filename)
							try:
								file1 = open(filename, "w")
								RecordData = 1
							except IOError:
								print("Could not open file")
						except IOError:
							print("Could not open file")
					
		finally: #restore keyboard echo
			pass
   
#Initialize Program
def Init():
	global numADCchan
	global voltage
	global qoi
	global vMulti
	
	for i in range(numADCchan):
		voltage[i] = 0
		qoi[i] = 0
		vMulti[i] = 1.0
		qUnits[i] = "Volts"
   
#Function to call at program exit
def ExitProgram(file1): 
	termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings) #Reset the keyboard settings
	try:
		if(file1.closed==False): file1.close() #close the file
		print("Recording stopped, closing file.")
	except AttributeError:
		pass
	time.sleep(0.5) #pause for 0.5 seconds
	sys.exit("Program Terminated.")
   
#Prints the header and data on the terminal screen
def PrintScreen():

	Screen1 = GenerateScreenStatic() #Generate the portion of the screen which does not poll data
	Screen2 = GenerateScreenDynamic()
	for i in range(len(Screen1)): print(Screen1[i])
	print()
	for i in range(len(Screen2)): print(Screen2[i])
	print()
	GenerateScreenControls()
	
#Generates the static part of the screen.  Not the scrolling data portion.
def GenerateScreenStatic():
	
	global numADCchan
	global voltage
	global vMulti
	global qoi
	global qoiOffSet 
	global qUnits 
	global ads
	global SampleFreq
	global SampleDTime

	now = datetime.now() #get the current date and time
	ScreenArray = [] #Array that holds the screen
	intSpacing = 10 #The string spaces to format data outputs

	PrintFormatHeader = "{:<4s} | {:^%ds} {:^%ds}" % (intSpacing, intSpacing)
	PrintFormatData = "{:<4s} | {:^%d,.5f} {:^%d,.5f}" % (intSpacing, intSpacing)

	ScreenArray.append(strProgramHeader)
	ScreenArray.append("Date Time is : {}\n".format(now.strftime("%Y_%m_%d %H:%M:%S")))
	ScreenArray.append("Filename = {}, ADS Gain = {:.3f}, Samp Freq = {} hz, Samp dt = {:.4f} s\n".format(outputfile, ads.gain,SampleFreq,SampleDTime))
		
	ScreenArray.append( PrintFormatHeader.format( "Chan", "QOI-Multi", "QOI-Offset" ) )
	for i in range(numADCchan): ScreenArray.append( PrintFormatData.format( "A"+str(i), vMulti[i], qoiOffSet[i] ) )
	
	return ScreenArray

#Generates the polling part of the screen
def GenerateScreenDynamic():
	global RecordData
	global numADCchan
	global voltage
	global vMulti
	global qoi
	global qoiOffSet 
	global qUnits 
	global SampleNumber
	global CurrentTime
	
	global voltageRNGval
	global voltageAVGval
	global qoiRNGval 
	global qoiAVGval 

	RecordStatus = "" #simple text variable for recording status
	
	intSpacing = 10 #The string spaces to format data outputs

	ScreenArray = [] #Array that holds the screen
	if (RecordData):	#Display the recording status
		RecordStatus = "Recording"
	else:
		RecordStatus = "Waiting"
	
	ScreenArray.append("Status = {} \tTime(s) = {:.3f} \tSample # = {}\n".format(RecordStatus,CurrentTime, SampleNumber))
		
	PrintFormatHeader = "{:<4s} | {:^%ds} {:^%ds} {:^%ds} | {:^%ds} {:^%ds} {:^%ds} | {:^8s}" % (intSpacing, intSpacing, intSpacing, intSpacing, intSpacing, intSpacing)
	PrintFormatData = "{:<4s} | {:^%d,.5f} {:^%d,.5f} {:^%d,.5f} | {:^%d,.5f} {:^%d,.5f} {:^%d,.5f} | {:^8s}" % (intSpacing, intSpacing, intSpacing, intSpacing, intSpacing, intSpacing)
	
	ScreenArray.append(PrintFormatHeader.format("Chan", "Voltage", "Volt-Avg", "Volt-Rng", "QOI", "QOI-Avg", "QOI-Rng", "Units"))
	for i in range(numADCchan): 
		ScreenArray.append(PrintFormatData.format( "A" + str(i), voltage[i], voltageAVGval[i], voltageRNGval[i], qoi[i], qoiAVGval[i], qoiRNGval[i], qUnits[i] ))
	
	return ScreenArray
	
#Generates the controls for the screen and the last notes
def GenerateScreenControls():
	global notes
	
	print("<0-3>zero QOI\t<space>Rec\t<c>Stop Rec\t<enter>Quit\n")
	print("Notes: "+notes)

#Records the ADC and determines voltages and qois
def RecordAndProcessADC():

	global numADCchan
	global voltage
	global vMulti
	global qoi
	global qoiOffSet 
		
	global numADCrange 
	global numADCaverage 
	global voltageRNGcnt 
	global voltageAVGcnt 
	global voltageRNG #= [[]*numADCchan]*numADCrange #Holds the samples to calculate the ranges
	global voltageAVG #= [[]*numADCchan]*numADCaverage #Holds the samples to calculate the averages
	global voltageRNGval #= [0]*numADCchan #Holds the range value for the channels
	global voltageAVGval #= [0]*numADCchan #Holds the average value for the channels
	global qoiRNGval #= [0]*numADCchan #Holds the range value for the channels
	global qoiAVGval #= [0]*numADCchan #Holds the range value for the channels
	
	VoltageMaxRNG = -10000.0 #holds the max range number
	VoltageMinRNG = 10000.0 #holds the min range number
	VoltageAVGsum = [0] * numADCchan #holds the sum of the voltages
				
	chan = [0] * numADCchan
	
	chan[0] = AnalogIn(ads, ADS.P0)
	chan[1] = AnalogIn(ads, ADS.P1)
	chan[2] = AnalogIn(ads, ADS.P2)
	chan[3] = AnalogIn(ads, ADS.P3)
	
	voltageRNGcnt += 1 #Increment counter
	voltageAVGcnt += 1 #Increment counter
		
	#Calculate and store voltages and qois
	for i in range(numADCchan): 
		voltage[i] = chan[i].voltage	#Store voltages
		qoi[i] = voltage[i]*vMulti[i] + qoiOffSet[i]	#Store qois
	
		voltageRNG[i][voltageRNGcnt-1] = voltage[i] 
		voltageAVG[i][voltageAVGcnt-1] = voltage[i] 
			
	if (voltageRNGcnt == numADCrange): #Determine the max-min range
		for i in range(numADCchan): 
			for j in range(numADCrange): #Go through each array index
				if (voltageRNG[i][j] > VoltageMaxRNG): #Determine VoltageMaxRNG
					VoltageMaxRNG = voltageRNG[i][j] 
				if (voltageRNG[i][j] < VoltageMinRNG): #Determine VoltageMinRNG
					VoltageMinRNG = voltageRNG[i][j] 
			voltageRNGval[i] = VoltageMaxRNG - VoltageMinRNG #Calculate the range for this channel
			qoiRNGval[i] = voltageRNGval[i]*vMulti[i] #+ qoiOffSet[i]	#Store qois
			VoltageMaxRNG = -10000.0 #holds the max range number
			VoltageMinRNG = 10000.0 #holds the min range number
		voltageRNGcnt = 0 #Reset counter
	
	if (voltageAVGcnt == numADCaverage): #Determine the average voltage for each channel
		for i in range(numADCchan): 
			VoltageAVGsum[i] = 0 #zero the sum
			for j in range(numADCaverage): #Go through each array index
				VoltageAVGsum[i]=VoltageAVGsum[i] + voltageAVG[i][j] #sum up all channel values
			voltageAVGval[i]=VoltageAVGsum[i] / numADCaverage #divide by the number of sampling averages
			qoiAVGval[i] = voltageAVGval[i]*vMulti[i] #+ qoiOffSet[i]	#Store qois
			
		voltageAVGcnt = 0 #Reset counter
		
#Writes the header and data to text file
def WriteDataToFile(filetowrite, SampleNumber, CurrentTime):

	global HeaderWritten
	global qUnits
		
	if (HeaderWritten): #Only write the data output lines since header is already written
		DataString = "{}\t{:.3f}\t{:.3f}\t{:.3f}\t{:.3f}\t{:.3f}\t{:.3f}\t{:.3f}\t{:.3f}\t{:.3f}\n".format(SampleNumber,CurrentTime,voltage[0],voltage[1],voltage[2],voltage[3],qoi[0],qoi[1],qoi[2],qoi[3])
		filetowrite.write(DataString) #write the next line of data
	else:
		Screen1 = GenerateScreenStatic() #Generate the portion of the screen which does not poll data
		for i in range(len(Screen1)): 
			filetowrite.write(Screen1[i]) #Write the static part of the header
			filetowrite.write("\n")
		filetowrite.write("\n")
		filetowrite.write( "Sample#\ttime(s)\tV0\tV1\tV2\tV3\tQOI0({})\tQOI1({})\tQOI2({})\tQOI3({})\n".format(qUnits[0],qUnits[1],qUnits[2],qUnits[3]) )
		HeaderWritten = 1 #Header is now written

def isData():
    return select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], [])
		
if __name__ == "__main__":
   main(sys.argv[1:])
