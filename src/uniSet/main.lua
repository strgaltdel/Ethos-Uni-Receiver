--[[
###################################################################################
#######																		#######
#######		    					"UNIset" 								#######
#######	  		an ETHOS lua tool to configure UNI-ACCST Receivers			#######
#######																		#######
#######	    		a Rx Firmware Project mainly driven by					#######
#######			 Mike Blandfort, Engel Modellbau and Aloft Hobby			#######
#######		   thanks to all who gave valuable information & inputs 		#######
#######																		#######
#######																		#######
#######																		#######
#######	 Rev 2.0	beta 4													#######
#######	 30 Oct  2024														#######
#######	 coded by Udo Nowakowski											#######
###################################################################################

		This program is free software: you can redistribute it and/or modify
		it under the terms of the GNU General Public License as published by
		the Free Software Foundation, either version 3 of the License, or
		(at your option) any later version.

		This program is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		GNU General Public License for more details.

		You should have received a copy of the GNU General Public License
		along with this program.  If not, see <https://www.gnu.org/licenses/>.
		
		0.8 		220405	roll out, no RxReset, no CRates due to missing bit32 lib
		1.0 RC1 	220410	added multiLang & intro, channel reset, bugfixing
		1.1 		221020	added Rx4R/Rx6R		
		1.2			221107	SPort timing
		1.3 		230217	masking Tuning Offset 
		
		1.4	beta1.2		240128	add settings for: fbus, cppm, D8cppm sbusC4, sbusC8, sportEnable ; 
							new Receiver detection G-Rx6/8 , XSR , R-XSR
							functional matrix (which rx supports which item)
							"dynamic" calculation of Page2
							some finetuning

							clean debug code
			beta 1.3    resolve paging bug
			beta 1.4 	resolve "no d8 sbus uninvert" parameter , no foo-fighter  on changing page

		2.0 beta1		240814   support Ethos >= 1.5.12
		2.0 beta2a		241030   support SxR
		2.0 beta3		241104   debug code added line 1665
		
		2.0 beta4		241104   reset issue  // rc1
*************************************************************************************  								


-- how to add ane option:
-- extend lang file, including txtIndex				
-- define index & txtIndex constant					
-- add line & params in RxField{}					
-- Rx_Reset table ??								OK
-- add entry in formpage										
-- add entry in sport2form()	(read Transformation)						
-- add entry/constant in rxIndex()						
-- add parameter in setvalue()			

some more hints:
- in case page1 / mapsbusline changes: adopt parametervalue in #100 (hardcoding)
- page 2 is dependent on rx type, several defs in function "builtPage2"


in order to add a new supported rx type:
(1)
add Rx in Forms choice list, according to UNI-ID (1=D series, 2= classic X8r/X6r...)
{name=txtFields[22][lan], 			d_item=0x09FF,	kind="Choice",	write_=0,	options={{"D8", 1}, {"X8R/X6R", 2}, {"X4R", 3}


(2)
add rx in function RecLookup:

local function RecLookup(index)
	local rx ={
		"D8",
		"X8/X6R",
		"X4R",
		"Rx8Rpro",
		"Rx8R",
		"Rx4/6R & Gx",
		"XSR",
		"R-XSR",
		"SXR"
		}

(3)
"matrix" of Rx type supported functionality is implemented in function filterPage(pageRaw,widget)	


--]]



local SPLASHTIME  = 2

local modeSim = false
--local modeSim = true
if modeSim then	SPLASHTIME  = 0 end

local translations = {en="UNIset 2.0"}
local lan								-- language 1=de

local function name(widget)					-- name script
	local locale = system.getLocale()
  return translations[locale] or translations["en"]
end



local SPORTtimeout = 0.2			--  timeout for sport push (sec)  // sim mode

if not(modeSim) then 
	SPORTtimeout = 1.4					-- operative mode
end


local debug0 <const> 		= false		-- debug level 0, basic
local debug1 <const> 		= false		-- monitor sport2form
local debug1b <const> 		= false		-- monitor sport2form item
local debug2 <const> 		= false		-- monitor wakeup
local debug3 <const> 		= false		-- dishandler_set
local debug4 <const> 		= false		-- get variable
local debug5 <const> 		= false		-- set variable
local debug6 <const> 		= false		-- form line create
local debug7 <const> 		= false		-- page 2 "dyn" line built
local debug8 <const>		= false		-- sxr debugging
local debug9 <const>		= false		-- reset monitor

local PageMaxValue  <const> 	= 6			-- max allowed pages
-- local forward			= true		-- turn page "next"
-- local backward 		 	= false		-- turn page "back"

-- ######################   check if this entry is right !!!! #########################
local MAPSbusLine <const> 	= 8				-- hardcoded, Formline  MapOnSbus , has to be adopted in case Para gets another "Place"

-- index names > RxField entries (better human reading)
--paras editable
local CH1_8CH9_16 <const> 	= 1
local PWM_on_SBUS <const> 	= 3
local Tune_Offset <const> 	= 5
local Tune_enable <const> 	= 6
local Puls_Rate <const> 	= 7
local MAPonPWM	<const> 	= 9
local MAPonSBUS	<const> 	=10
local CHAN_Mapping	<const> =11
local SBusNotInvert <const>	=12
-- read only
local FWRevision <const> 	=20
local RxProtocol <const> 	=21
local RxType <const> 		=22
local RxReset <const> 		=25
local HEADER1 <const> 		=26
local HEADER2 <const> 		=27
local HEADER3 <const> 		=28
local HEADER4 <const> 		=29
local HEADER5 <const> 		=30
local HEADER6 <const> 		=31


local FBUSMODE <const>		= 32		-- Rev 1.4
local txtFBUSMODE <const>	= 26		-- index language array	
local INFO <const> 			= 33
local txtINFO <const> 		= 27
local CPPM <const>			= 34
local txtCPPM <const>		= 28
local D8CPPM <const>		= 35	
local txtD8CPPM <const>		= 29
local SPORTENABLE <const>	= 36
local txtSPORTENABLE <const> = 30
local SBUSC4 <const>		= 37
local txtSBUSC4 <const>		= 31
local SBUSC8 <const>		= 38
local txtSBUSC8 <const>		= 32		-- ..Rev 1.4



local RunOnStart 	= true
local introHandler = 0

local frame = {}							-- Sport frame data items
local chMap = {}							-- chsannel map
local txid = 0x17							-- txid used by sport
local fields = {}


local parameters = {}						-- raw array to built formsheet 
local formPage = {}							-- form layout (line definitions)
local APP_ID= 0x0C20						-- classic Rx type (Sx=0x0C30)

local DIT_RECEIVER <const> = 0x09FF
local DIT_PROTOCOL <const> = 0x08FF
local DIT_REVISION <const> = 0x07FF

local resetFlag = false						-- reset active or not
local writeInterval = 0.15					-- minimum Sport Push interval (experimental)
local nextWrite = 0					
local resetcounter = 1	


local startTime = 0
local uni_leftTime = 0
	
local updateForm 	= true															-- flag new form
local PageMax 		= P0												-- number of pages (formsheets)
local PageActual 	= 1																-- page which is displayed
local PageNext		= PageActual	
local PageLast		= 2		



local txtFields,optionLan,header = dofile("lang.lua")		-- get language file
 
local PAGESTRG
local locale = system.getLocale()
	if locale =="de" then
		lan = 1
		PAGESTRG 	="Seite"
--  elseif locale == "fr" then lan = 3		-- to be expanded
	else
		lan = 2 							-- not supported language, so has to be "en"
	PAGESTRG 	="Page"		
	end
	



	

-- "core" array / list of sport items 
-- 	line name (form)					data address	type of field	write enabled		line options								SPort value, default val(form),  SPort default,		form value,			disable others, 	index
--																		(or dependent from)																												.. dishandler_set()
--																		parameter[5]																														parameter[6]


local RxField = {														
	{name=txtFields[1][lan], 		d_item=0x00E0,	kind="Choice",	write_=1,			options={{"1-8", 0}, {"9-16", 1}},			value=nil,	default=0			,SPortdefault=0x00E0	,formVal=nil,	disable=false,	index = CH1_8CH9_16	},			--  1 upper/lower channels on servo outputs; 1=9-16
	{name=txtFields[2][lan], 		d_item=0x00E1,	kind="Choice",	write_=1,			options=nil,								value=nil,	default="obsolet"	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 2			},			--  2 dummy
	{name=txtFields[3][lan], 		d_item=0x00E2,	kind="Boolean",	write_=1,			options=nil,								value=nil,	default=false		,SPortdefault=0x00E2	,formVal=nil,	disable=false,	index = PWM_on_SBUS	},			--  3 sbus Out = additional pwm channel; 1=enabled	
	{name=txtFields[4][lan], 		d_item=0x00E3,	kind="Choice",	write_=1,			options=nil,								value=nil,	default="obsolet"	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 4			},			--  4 dummy
	{name=txtFields[5][lan], 		d_item=0x00E4,	kind="Number",	write_=0,			minimum=-200, maximum=200,					value=nil,	default=20			,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = Tune_Offset	},			--  5 tuning offset  -127..+127	
	{name=txtFields[6][lan], 		d_item=0x00E5,	kind="Boolean",	write_=1,			options=nil,								value=nil,	default=false		,SPortdefault=0x01E5	,formVal=nil,	disable=false,	index = Tune_enable	},			--  6 tuning enabled 1=enabled	
	{name=txtFields[7][lan], 		d_item=0x00E6,	kind="Choice",	write_=1,			options={{"9ms", 1}, {"18ms", 0}},			value=nil,	default=0			,SPortdefault=0x00E6	,formVal=nil,	disable=false,	index = Puls_Rate	},			--  7 servo pulse period 1=9ms
	{name=txtFields[8][lan], 		d_item=0x00E7,	kind="Choice",	write_=1,			options=nil,								value=nil,	default="obsolet"	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 8			},			--  8 servo pulse period 1=9ms	on dedicated servo outputs bit0=Ch1
	{name=txtFields[9][lan], 		d_item=0x00E8,	kind="Boolean",	write_=1,			options=nil,								value=nil,	default=false		,SPortdefault=0x00E8	,formVal=nil,	disable=true,	index = MAPonPWM	},			--  9 bit0: servo output enabled;  bit1: SBus output enabled
	{name=txtFields[10][lan], 		d_item=0x00E8,	kind="Boolean",	write_=MAPonPWM,	options=optionLan[1][lan],					value=nil,	default=false		,SPortdefault=0x00E8	,formVal=nil,	disable=false,	index = MAPonSBUS	},
	{name=txtFields[11][lan], 		d_item=0x00E9,	kind="Channel",	write_=MAPonPWM,	options=nil,								value=nil,	default=0			,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = CHAN_Mapping},			-- 11 two Bytes; 1st: output index#; 2nd channel to be used
	{name=txtFields[12][lan], 		d_item=0x00EA,	kind="Choice",	write_=1,			options=optionLan[2][lan],					value=nil,	default=0			,SPortdefault=0x00EA	,formVal=nil,	disable=false,	index = SBusNotInvert},			-- 12 standard: inverted (0)

-- read only
	{name="Total dropped packets", 		d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=3	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 13			},			-- 13 data 0
	{name="CRC Errors", 				d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=4	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 14			},			-- 14 data 1
	{name="Drop Percent", 				d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=5	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 15			},			-- 15 data 2
	{name="Ave Packet time)", 			d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=6	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 16			},			-- 16 data 3	
	{name="Telemetry resets)", 			d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=7	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 17			},			-- 17 data 4
	{name="Antenna swaps",				d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=8	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 18			},			-- 18 data 5	
	{name="Telemetry not sent (times)",	d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=9	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 19			},			-- 19 data 6
	{name="Software Rev", 				d_item=0x07FF,	kind="Choice",	write_=0,	value=nil,	default=10	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 20			},			-- 20 data 7
	{name=txtFields[21][lan], 			d_item=0x08FF,	kind="Choice",	write_=0,	options={{"V1 FC", 0}, {"V1 EU", 1}, {"V2 FC", 2}, {"V2 EU"	, 3}},	value=nil,	default=1	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = RxProtocol	},			-- 21 data 8
	{name=txtFields[22][lan], 			d_item=0x09FF,	kind="Choice",	write_=0,	options={{"D8", 1}, {"X8R/X6R", 2}, {"X4R", 3}, {"Rx8Rpro", 4}, {"Rx8R", 5}, {"Rx4/6R & Gx", 6},{"XSR", 7}, {"R-XSR", 8}, {"SXR", 9}		},	value=nil,SPortdefault=0x00FF	,	default=1	,formVal=nil,	disable=false,	index = RxType		},			-- 22 data 9
	{name="Antenna count[0]", 			d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=13	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 23			},			-- 23 data10
	{name="Antenna count[1]", 			d_item=0x00FF,	kind="Choice",	write_=1,	value=nil,	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 24			},			-- 24 data11
	
	{name="Rx Reset",					d_item=0x30,	kind="TxtButton",	write_=1,	value=nil,	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = 25},
	
	{name="header1",					d_item=0x30,	kind="page",	write_=0,	value="<- 1 ->",	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = HEADER1},
	{name="header2",					d_item=0x30,	kind="page",	write_=0,	value="<- 2 ->",	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = HEADER2},
	{name="header3",					d_item=0x30,	kind="page",	write_=0,	value="<- 3 ->",	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = HEADER3},
	{name="header4",					d_item=0x30,	kind="page",	write_=0,	value="<- 4 ->",	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = HEADER4},
	{name="header5",					d_item=0x30,	kind="page",	write_=0,	value="<- 5 ->",	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = HEADER5},
	{name="header6",					d_item=0x30,	kind="page",	write_=0,	value="<- 6 ->",	default=14	,SPortdefault=0x00FF	,formVal=nil,	disable=false,	index = HEADER6},
	
	-- Rev 1.4 additions:
	{name=txtFields[txtFBUSMODE][lan], 	d_item=0x00EC,	kind="Boolean",	write_=1,	options=nil,		value=nil,	default=false		,SPortdefault=0x00EC	,formVal=nil,			disable=false,	index = FBUSMODE	},			-- 35 FBUS active on S.Port
	{name=txtFields[txtINFO][lan],		d_item=0x00FF,	kind="Txt",		write_=0,	value="reading from Rx",			default="??"	,SPortdefault=0x00FF	,formVal="reading ",	disable=true,	index = INFO},
	
	{name=txtFields[txtCPPM][lan], 		d_item=0x00E3,	kind="Boolean",	write_=1,	options=nil,		value=nil,	default=false		,SPortdefault=0x00E3	,formVal=nil,			disable=false,	index = CPPM	},	
	{name=txtFields[txtD8CPPM][lan], 	d_item=0x00ED,	kind="Boolean",	write_=1,	options=nil,		value=nil,	default=false		,SPortdefault=0x00ED	,formVal=nil,			disable=false,	index = D8CPPM	},	
	{name=txtFields[txtSPORTENABLE][lan],d_item=0x00E3,	kind="Boolean",	write_=1,	options=nil,		value=nil,	default=false		,SPortdefault=0x00E3	,formVal=nil,			disable=false,	index = SPORTENABLE	},	
	{name=txtFields[txtSBUSC4][lan], 	d_item=0x00E2,	kind="Boolean",	write_=1,	options=nil,		value=nil,	default=false		,SPortdefault=0x00E2	,formVal=nil,			disable=false,	index = SBUSC4	},
	{name=txtFields[txtSBUSC8][lan], 	d_item=0x00E1,	kind="Boolean",	write_=1,	options=nil,		value=nil,	default=false		,SPortdefault=0x00E1	,formVal=nil,			disable=false,	index = SBUSC8	},	
}

for i =1,#RxField do
	RxField[i].formVal = nil
end

RxField[INFO].formVal ="READING DATA"											-- fill Info Field

	



local 	lookupRxPnt = {}
		lookupRxPnt[1]  = "channel 1-8 / 9-16"
		lookupRxPnt[3]  = "PWM_on_SBUS"
		lookupRxPnt[5]  = "Tune_Offset"
		lookupRxPnt[6]  = "Tune_enable"
		lookupRxPnt[7]  = "Puls_Rate"
		lookupRxPnt[9]  = "MAPonPWM"
		lookupRxPnt[10] = "MAPonSBUS"
		lookupRxPnt[11] = "CHAN_Mapping"
		lookupRxPnt[12] = "SBusNotInvert"
		lookupRxPnt[20] = "FWRevision"
		lookupRxPnt[21] = "RxProtocol"
		lookupRxPnt[22] = "RxType"
		lookupRxPnt[25] = "Reset Button"
		lookupRxPnt[32] = "FBUSMODE"
		lookupRxPnt[33] = "INFO"
		lookupRxPnt[34] = "CPPM"
		lookupRxPnt[35] = "D8CPPM"
		lookupRxPnt[36] = "SPORTENABLE"
		lookupRxPnt[37] = "SBUSC4"
		lookupRxPnt[38] = "SBUSC8"


																							-- ************************************************
																							-- *****  List of entries to be resetted    *******
																							-- ************************************************
local Rx_Reset = {
	CH1_8CH9_16,
	PWM_on_SBUS,
	Tune_enable,
	Puls_Rate,
	MAPonPWM,
	SBusNotInvert,
	FBUSMODE,
	CHAN_Mapping}
	
	

																							-- ********************************************
																							-- *********     form definition       ********
																							-- ********************************************


formPage[1] =							-- form page1
{
	
  	{pointer =	HEADER1},	
  	{pointer =	33	},		-- calculated info line
	{pointer =	RxField[Tune_enable].index	},			-- 4 TuneOffset
	{pointer =	RxField[Tune_Offset].index	},  		-- 5 TuneValue 
  	{pointer =	RxField[CH1_8CH9_16].index	},		-- 6 Chans9_16
  	{pointer =	RxField[Puls_Rate].index	},	 	-- 7 Puls_Rate
  	{pointer =	RxField[MAPonPWM].index		},		-- 9 Map on PWM	; should be on 1st page to determine #pages (sport2form)
  	{pointer =	RxField[MAPonSBUS].index	}		--10 Map on SBUS 

  }




  
formPage[3] =							-- form page3
{  
 -- {"                                  Kanalzuordnung 1",	"TextOnly","PAGE 3/6"},
								--			value, default
  {pointer =	HEADER3},	
  {pointer =	RxField[CHAN_Mapping].index, chNum = 1	},						 											--11 channel 1 mapping
  {pointer =	RxField[CHAN_Mapping].index, chNum = 2	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 3	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 4	}
  }
  
  
formPage[4] =							-- form page4
{ 
--  {"                                  Kanalzuordnung 2",	"TextOnly","(4/6)"},
  {pointer =	HEADER4},	
  {pointer =	RxField[CHAN_Mapping].index, chNum = 5	},						 											--11 channel 1 mapping
  {pointer =	RxField[CHAN_Mapping].index, chNum = 6	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 7	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 8	}
  }
  
formPage[5] =							-- form page5
{ 
--{"                                  Kanalzuordnung 3",	"TextOnly","(5/6)"},
  {pointer =	HEADER5},	
  {pointer =	RxField[CHAN_Mapping].index, chNum = 9	},						 											--11 channel 1 mapping
  {pointer =	RxField[CHAN_Mapping].index, chNum = 10	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 11	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 12	}
  }
  
formPage[6] =							-- form page6
{ 
  --{"                                  Kanalzuordnung 4",	"TextOnly","(6/6)"},  
    {pointer =	HEADER6},	
  {pointer =	RxField[CHAN_Mapping].index, chNum = 13	},						 											--11 channel 1 mapping
  {pointer =	RxField[CHAN_Mapping].index, chNum = 14	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 15	},						
  {pointer =	RxField[CHAN_Mapping].index, chNum = 16	}
  }

																			-- ************************************************
																			-- *****   		workaround get time     	*******
																			-- ************************************************
local function getTime()
  return os.clock()		 
end




local intro 
local uni_left= false
local uni_leftTime
local bitmap1_flag = false
local bit_mp = "engelmt.bmp"




local function RecLookup(index)
	local rx ={
		"D8",
		"X8/X6R",
		"X4R",
		"Rx8Rpro",
		"Rx8R",
		"Rx4/6R & Gx",
		"XSR",
		"R-XSR",
		"SXR"
		}
		
	return rx[index]
end


local function protoLookup(index)
	local prot ={
			"V1-FC", 
			"V1-EU", 
			"V2-FC",
			"V2-EU",
		}

	return prot[index+1]
end

																			-- ************************************************
																			-- *****   workaround missing bit32 lib     *******
																			-- ************************************************
local function bitband_FF(value)
	--value = value-math.floor(value/256)*256
	value = value&0x00FF
	return value
end



																			-- **************************************************************
																			-- ********  transform SPort Value into Form Value   		*****
																			-- ********	is called by wakeup loop, when data was read	*****
																			-- **************************************************************

local function sport2form(value, fieldId, parameter, rxIndex,widget)
local result
	if fieldId == 0x09FF then																								-- RxType  data9 from FF
				value = math.floor(value / (256*256))
				rxIndex = RxType
				RxField[rxIndex].value = bitband_FF(value)
				RxField[rxIndex].formVal = RxField[RxType].value	
				

				result = RxField[rxIndex].formVal
				if debug1b then print("== set RxType",value) end
				receiver = rxlookup(RxField[rxIndex].value)
				if debug1 then print("====  READitem 09ff Receiver",RxField[RxType].name,RxField[RxType].formVal,RxField[rxIndex].value, widget.receiver ) end

	
				
	elseif fieldId == 0x08FF then																							-- Rx protocol data8 from FF
				value = math.floor(value / (256*256))	
				RxField[rxIndex].value = bitband_FF(value)
				RxField[rxIndex].formVal = RxField[RxProtocol].value	
				rxIndex = RxProtocol	
				result = RxField[rxIndex].formVal	
				if debug1b then print("== set Protocol",value) end
				if debug1 then print("====  READitem 08FF",RxField[RxProtocol].name,RxField[RxProtocol].formVal ) end
				
				
	elseif fieldId == 0x07FF then																								-- revision  data7 from FF
				value = math.floor(value / (256*256))
				rxIndex = FWRevision
				RxField[rxIndex].value = bitband_FF(value)
				RxField[rxIndex].formVal = RxField[RxType].value	
				result = RxField[rxIndex].formVal
				if debug1b then print("== set Revision",value) end
				revision = rxlookup(RxField[rxIndex].value)
				if debug1 then print("====  READitem 09ff Receiver",RxField[RxType].name,RxField[RxType].formVal,RxField[rxIndex].value, widget.receiver ) end
	
	
	elseif rxIndex == CH1_8CH9_16 or rxIndex == Puls_Rate  or  rxIndex == SBusNotInvert or rxIndex == Tune_Offset   then	-- simple choice/num field	
				value = math.floor(value / 256)	
				RxField[rxIndex].value = bitband_FF(value)
				
				if rxIndex == Tune_Offset and RxField[rxIndex].value > 128 then												-- mask Offset value -127..+127
					RxField[rxIndex].value = RxField[rxIndex].value -256
				end
				
				RxField[rxIndex].formVal = RxField[rxIndex].value
				if debug1 then print("====  READitem",RxField[rxIndex].name,RxField[rxIndex].formVal ) end
				result = RxField[rxIndex].formVal

				
	elseif rxIndex == PWM_on_SBUS  or rxIndex == Tune_enable or rxIndex == FBUSMODE  or rxIndex == CPPM  or rxIndex == D8CPPM  or rxIndex == SPORTENABLE  or rxIndex == SBUSC4 or rxIndex == SBUSC8 then										-- simple boolean handling
				value = math.floor(value / 256)	
				RxField[rxIndex].value = bitband_FF(value)
				if RxField[rxIndex].value > 0 then
					RxField[rxIndex].formVal = true
				else
					RxField[rxIndex].formVal = false			
				end
				if debug1 then print("====  READitem",RxField[rxIndex].name,RxField[rxIndex].formVal ) end
				result = RxField[rxIndex].formVal

				
	elseif rxIndex == MAPonPWM or rxIndex == MAPonSBUS then																	-- bit field from d_item=0x00E8
				value = math.floor(value / 256)	
				value = bitband_FF(value)
				if debug1b then print ("====  READitem MAPVALUE",RxField[rxIndex].name,value) end
				if value > 0 then																							-- servo mapping enabled
					RxField[MAPonPWM].value = value
					RxField[MAPonPWM].formVal = true
					PageMax = PageMaxValue
					print("486 set maxpage pwm",PageMax)
					if debug1 then print("set map",RxField[MAPonPWM].formVal) end
					if value > 1 then																						-- in addition, sbus mapping enabled
						RxField[MAPonSBUS].value = value
						RxField[MAPonSBUS].formVal = true	
						if debug1 then print("set mapBUS",RxField[MAPonSBUS].formVal) end
					else
						RxField[MAPonSBUS].value = value
						RxField[MAPonSBUS].formVal = false	
						if debug1 then print("set mapBUS",RxField[MAPonSBUS].formVal)	 end				
					end
				else																											-- no mapping
					PageMax = 2			
					if debug1b then print("499 set maxpage pwm",PageMax) end																					-- so disable cannel mapping pages
					RxField[MAPonPWM].value = value
					RxField[MAPonPWM].formVal = false
					RxField[MAPonSBUS].value = value
					RxField[MAPonSBUS].formVal = false	
					if debug1 then print("set map",RxField[MAPonPWM].formVal,RxField[MAPonSBUS].formVal) end
				end
				result = RxField[rxIndex].formVal
				if debug1 then print("====  READitem result",RxField[rxIndex].name,RxField[rxIndex].formVal )	 end

				
	elseif CHAN_Mapping then	
			value = math.floor(value / 256)											-- extract chValue and chNumber
			local ch_num = value&0x00FF												-- extract chNum
			local ch_num = ch_num+1
			value = math.floor(value / 256)											-- extract chValue
			if debug1 then print("reading Channel num",ch_num,value) end
			chMap[ch_num]=value+1
			result=chMap[ch_num]
			if debug1 then print("setchannelNum",ch_num,value) end

	end
	return(result)
end


																			-- *****************************************************************
																			-- ***********  evaluate RxField-array  related index from line
																			-- ***********  needed  for write enabled fields
																			-- ***********	!! should be more intelligent (-;
																			-- *****************************************************************
local function rxIndex(parameter)											
	local rxPointer
	if parameter[1] == txtFields[CH1_8CH9_16][lan] then
		rxPointer = CH1_8CH9_16

	elseif parameter[1] == txtFields[PWM_on_SBUS][lan] then
		rxPointer = PWM_on_SBUS

	elseif parameter[1] == txtFields[Tune_Offset][lan]	 then
		rxPointer = Tune_Offset		
		
	elseif parameter[1] == txtFields[Tune_enable][lan] then
		rxPointer = Tune_enable		
		
	elseif parameter[1] == txtFields[Puls_Rate][lan] then	
		rxPointer = Puls_Rate	
		
	elseif parameter[1] == txtFields[MAPonPWM][lan] then
		rxPointer = MAPonPWM	
		
	elseif parameter[1] == txtFields[ MAPonSBUS][lan] then
		rxPointer = MAPonSBUS

	elseif parameter[1] == txtFields[SBusNotInvert][lan] then
		rxPointer = SBusNotInvert
		
	elseif parameter[1] == txtFields[RxProtocol][lan] then
		rxPointer = RxProtocol
		
	elseif parameter[1] == txtFields[RxType][lan] then
		rxPointer = RxType
	
	elseif parameter[1] == txtFields[txtFBUSMODE][lan] then
		rxPointer = FBUSMODE

	elseif parameter[1] == txtFields[txtCPPM][lan] then
		rxPointer = CPPM
		
	elseif parameter[1] == txtFields[txtD8CPPM][lan] then
		rxPointer = D8CPPM
		
	elseif parameter[1] == txtFields[txtSPORTENABLE][lan] then
		rxPointer = SPORTENABLE
		
	elseif parameter[1] == txtFields[txtSBUSC4][lan] then
		rxPointer = SBUSC4
		
	elseif parameter[1] == txtFields[txtSBUSC8][lan] then
		rxPointer = SBUSC8



	elseif parameter[1] == txtFields[txtINFO][lan] or parameter[6]=="info" then
		rxPointer = INFO


		
	elseif parameter[1] == ">>" or  parameter[1] =="Coding by Udo Nowakowski" then
		rxPointer = RxReset
		
	elseif parameter[1] ==PAGESTRG  then
		if 		parameter[3] == "<- 1 ->" then rxPointer = HEADER1
		elseif 	parameter[3] == "<- 2 ->" then rxPointer = HEADER2 
		elseif 	parameter[3] == "<- 3 ->" then rxPointer = HEADER3 
		elseif 	parameter[3] == "<- 4 ->" then rxPointer = HEADER4 
		elseif 	parameter[3] == "<- 5 ->" then rxPointer = HEADER5 
		elseif 	parameter[3] == "<- 6 ->" then rxPointer = HEADER6 
		end
		
	elseif string.sub(parameter[1],1,3) == "Ch " then
		rxPointer = CHAN_Mapping
	end

	return(rxPointer)
end




																			-- *******************************************************************************
																			-- ********   evaluate if field enabling is dependent from other values  *********
																			-- *******************************************************************************
local function dishandler_get(parameter,rxPointer)

		if rxPointer == MAPonSBUS then															-- map on sbus dependency: "Mapping on PWM" disabled ?	
			if RxField[MAPonPWM].formVal == false or RxField[MAPonPWM].formVal == nil then		-- request status "parent" condition
				RxField[MAPonSBUS].formVal 	= false												-- reset values
				RxField[MAPonSBUS].value 	= 0
			--	print("598 F2 dis_get",fields[MAPSbusLine],rxPointer,MAPonSBUS)
			--	fields[MAPSbusLine]:enable(false)											-- disable SBUS mapping field (hardcoded !!)
				PageMax = 2	
			--	print("629 set maxpage maponSBUS",PageMax)
				return(false)													-- disable channel mapping config
			else
				fields[MAPSbusLine]:enable(true)
				PageMax = PageMaxValue	
			--	print("634 set maxpage maponSBUS",PageMax)
				return(true)
			end
																								-- ch map handling on start (rx not read/ vars initialized, so no mapping page)
		elseif rxPointer == CHAN_Mapping then
			if RxField[MAPonPWM].formVal == false or RxField[MAPonPWM].formVal == nil then
				return(false)																	-- return false, so disable channel mapping pages
			end
		end
		return(true)
end

																			-- ***************************************************************
																			-- ********   line value triggers disabling other lines   ********
																			-- ***************************************************************


local function dishandler_set(parameter)
																								-- !! "hardcoded" line position of parameter in field array  >> MAPSbusLine
	local rxPointer = rxIndex(parameter)
	if rxPointer == MAPonPWM then																-- exeption (1): handle "Mapping on PWM" disabled	
	if debug3 then print("+++++ map on pwm detected, set to",RxField[MAPonPWM].formVal) end
			if RxField[MAPonPWM].formVal == false then											-- check if map on PWM disabled	; has to be "iverted" because called before set option
				if debug3 then print("set exception",parameter[4]) end
				RxField[MAPonSBUS].formVal 	= false												-- reset form value
				RxField[MAPonSBUS].value 	= 0													-- no SBUS mapping 
				if debug3 then print("++info pre set sbus",parameters[4][1],parameters[4][4]) end
				fields[MAPSbusLine]:enable(false)												-- disable SBUS mapping field / field line #4 (hardcoded !!)
				-- print("662 set maxpage pwm",PageMax)
				PageMax = 2																		-- disable channel mapping config
			else
				fields[MAPSbusLine]:enable(true)												-- else: enable field & channel map
				PageMax = PageMaxValue	
				-- print("666 set maxpage pwm",PageMax)
				if debug3 then print("set exception pwm",parameter[4]) end
			end
	end

end





																			-- *****************************************************************
																			-- ***********  function called in in order to get new value in form
																			-- *****************************************************************

local function getValue(parameter)

	local rxPointer = rxIndex(parameter)
	if rxPointer == CHAN_Mapping then
		local ChanNum = tonumber(string.sub(parameter[1],4,5))							-- extract channel number
		if chMap[ChanNum] == nil then
			chMap[ChanNum] = ChanNum													-- default
			parameter[4] = chMap[ChanNum]
		end		
		if debug4 then print("getchannel", ChanNum,chMap[ChanNum] ) end
		return chMap[ChanNum]															-- return value

	else																				-- standard handling
		if parameter[4] == nil then
			if debug4 then print ("get returns default") end
			-- return RxField[rxPointer].default										-- andreas requested nil
		else
			if debug4 then print ("ItemIdx",rxPointer,"get returns",RxField[rxPointer].value) end
			return RxField[rxPointer].formVal
		end							
	end
end






																			-- ********************************************************************
																			-- ***		  function called in case new value set in form			***   
																			-- ***		     calculate SPort Values & "flag" SPORT write   		*** 
																			-- ***		        by using modifications array       				***																			
																			-- ***		            returns formValue      						***
																			-- ********************************************************************


local function setValue(parameter, value)													-- corresponding MB "changesetup" function
	local newValue
	local rxPointer = rxIndex(parameter)
	local returnVal
	if debug5 then print("..729 enter setval",parameter[1],"para6:", parameter[6],"pointer:",rxPointer ,parameter[4],value) end
	
	if 	string.sub(parameter[1],1,3) == "Ch " then										-- probe channel field
		local ChanNum = tonumber(string.sub(parameter[1],4,5))							-- extract channel number
		parameter[4]=value																-- set active Form value
		chMap[ChanNum] = parameter[4]													-- set channel value in array
		newValue = 0xE9 + (ChanNum-1)*256												-- workaround caused by missing bit32 lib; add byte1/ChNum   to item
		newValue = newValue + (value-1) * 65536											-- workaround caused by missing bit32 lib; add byte2/ChValue to item
		modifications[1] = {parameter[3], newValue}	
		if debug5 then print ("set channelMap detected",string.format("%x",newValue)) end
	else
		parameter[4]=value																-- set value in actual form line
		RxField[rxPointer].formVal = value												-- cache value in case of page up/dwn

		if parameter[6]	then															-- disable other lines detected
			dishandler_set(parameter,value)												-- so handle field disabling
		end
	
		if rxPointer == CH1_8CH9_16 then
			if value == 0 then
				newValue = 0x00E0
			else
				newValue = 0x01E0
			end
			modifications[1] = {parameter[3], newValue}										-- set {dataitem,value} for wakeup processing
			if debug5 then print ("754 set channelblock detected",string.format("%x",newValue)) end

			
		elseif rxPointer == PWM_on_SBUS then		
			if value == false then
				newValue = 0x00E2
			else
				newValue = 0x01E2
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("764 set ServoOnSbus detected",string.format("%x",newValue)) end

			
		elseif rxPointer == Tune_enable then
			if value == false then
				newValue = 0x00E5
			else
				newValue = 0x01E5
			end
			modifications[1] = {parameter[3], newValue}			
			if debug5 then print ("set TuningEnable detected",string.format("%x",newValue)) end
	
	
		elseif rxPointer == Puls_Rate then		
			if value == 1 then
				newValue = 0x01E6
				modifications[2] = {parameter[3], 0x01FFE7}		-- 18ms all channels
			else
				newValue = 0x00E6
				modifications[2] = {parameter[3], 0x00E7}		-- 09 ms all channels
			end
			modifications[1] = {parameter[3], newValue}											-- set {dataitem,value} for wakeup processing	
			if debug5 then print ("set PulsRate detected",string.format("%x",newValue)) end

		elseif rxPointer == MAPonPWM then
			if value == false then
				newValue = 0x00E8
			else
				if RxField[MAPonSBUS].formVal then
					newValue = 0x03E8															-- map PWM & SBus
				else
					newValue = 0x01E8															-- map PWM only
				end
			end
			modifications[1] = {parameter[3], newValue}
			if debug5 then print ("set MapPWM detected",string.format("%x",newValue)) end

			
		elseif rxPointer == MAPonSBUS then		
			if value then
					newValue = 0x03E8															-- map PWM & SBus
			else
					newValue = 0x01E8															-- map PWM only
			end
			modifications[1] = {parameter[3], newValue}
			if debug5 then print ("set MapSbus detected",string.format("%x",newValue)) end

			
		elseif rxPointer == SBusNotInvert then	
			if value == 0 then
				newValue = 0x00EA
			else
				newValue = 0x01EA
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set SBus inverted detected",string.format("%x",newValue)) end
		
		
		elseif rxPointer == FBUSMODE then	
			if value then
				newValue = 0x01EC
			else
				newValue = 0x00EC
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set fbusMODE detected",string.format("%x",newValue)) end

		elseif rxPointer == CPPM then	
			-- print("825 elseif cppm",value)
			if value then
				newValue = 0x00E3
			else
				newValue = 0x00E3
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set CPPM detected",string.format("%x",newValue,value)) end


		elseif rxPointer == D8CPPM then	
			if value then
				newValue = 0x01ED
			else
				newValue = 0x00ED
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set D8CPPM detected",string.format("%x",newValue)) end
	

		elseif rxPointer == SPORTENABLE then	
			if value then
				newValue = 0x01E3
			else
				newValue = 0x00E3
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set SPORTENABLE detected",string.format("%x",newValue)) end


		elseif rxPointer == SBUSC4 then	
			if value  then
				newValue = 0x01E2
			else
				newValue = 0x00E2
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set SBUSC4 detected",string.format("%x",newValue)) end
		
	
		elseif rxPointer == SBUSC8 then	
			if value then
				newValue = 0x01E1
			else
				newValue = 0x00E1
			end
			modifications[1] = {parameter[3], newValue}	
			if debug5 then print ("set SBUSC8 detected",string.format("%x",newValue)) end	


		elseif rxPointer == RxReset then	
			if debug5 then print ("set RxReset detected") end
			resetFlag = true
			nextWrite = getTime() + writeInterval
			return("OK")
		end		
	return(RxField[rxPointer].formVal)
	end

end

																			-- ************************************************
																			-- ***		    create new form line   			*** 
																			-- ***         return new "field line"			***
																			-- ************************************************
															
local function createNumberField(line, parameter)
	local field = form.addNumberField(line, nil, parameter[7], parameter[8], function() return getValue(parameter) end, function(value) setValue(parameter, value) end)
	field:enableInstantChange(false)
	if parameter[5] ~= 0 then 												-- if write enabled >>
		field:enable(true)
		--field:enable(false)
	else
		field:enable(false)
	end
	return field
end



local function createBooleanField(line, parameter)
	local field = form.addBooleanField(line, nil, function() return getValue(parameter) end, function(value) setValue(parameter, value)  end)
	if parameter[5] ~= 0  then 												-- if write enabled >>
		--field:enable(true)
		field:enable(false)
	else
		field:enable(false)
	end
	return field
end



local function createChoiceField(line, parameter)
   local field = form.addChoiceField(line, nil, parameter[7], function() return getValue(parameter) end, function(value) setValue(parameter, value) end)

	if parameter[5] ~= 0  then 													-- if write enabled >>
		--field:enable(true)
		field:enable(false)
	else
		field:enable(false)
	end
  return field
end


local function createChannelField(line, parameter)								
	local field = form.addNumberField(line, nil, 1,	16, function() return getValue(parameter)  end, function(value) setValue(parameter, value ) end)

	if parameter[5] ~= 0  then 												-- if write enabled >>
		field:enable(true)
	else
		field:enable(false)
	end
	field:enableInstantChange(true)
	return field
end



local function createTextButton(line, parameter)
  local field = form.addTextButton(line, nil, parameter[4], function() return setValue(parameter,"done, Reset again ?") end)
  return field
end



local function createTextOnly(line,parameter,inx)
  local field = form.addStaticText(line, nil, parameter[3])
  return field
end

local function createTextField(line,parameter)
	local field = form.addTextField(line, nil, function()   return getValue(parameter) end, function(newValue)   setValue(parameter, newValue) end)
	return field
  end






																			-- ************************************************
																			-- ***		       "wrapper" function     		*** 
																			-- ***           inspired by "Servo script"		***
																			-- ***          builts an array "parameters"	***
																			-- ***          sourced by RxField definitions	***
																			-- ************************************************



local function built_para()													-- wrapper: transform page dependent RxField description into clean "parameters" array
  parameters = {}															-- clear artefacts
  for index = 1, #formPage[PageActual] do

	local kind 	= RxField[formPage[PageActual][index].pointer].kind
	local name	= RxField[formPage[PageActual][index].pointer].name
	local dItem	= RxField[formPage[PageActual][index].pointer].d_item

	if kind == "Number" then
		parameters[index] =	{name,	createNumberField,	dItem,	nil,RxField[formPage[PageActual][index].pointer].write_	,RxField[formPage[PageActual][index].pointer].disable	,	RxField[formPage[PageActual][index].pointer].minimum,		RxField[formPage[PageActual][index].pointer].maximum}

	elseif kind == "Choice" then
		parameters[index] =	{name,	createChoiceField,	dItem,	RxField[formPage[PageActual][index].pointer].formVal ,RxField[formPage[PageActual][index].pointer].write_	,RxField[formPage[PageActual][index].pointer].disable	,	RxField[formPage[PageActual][index].pointer].options}	

	elseif kind == "Boolean" then
		parameters[index] =	{name,	createBooleanField,	dItem,	RxField[formPage[PageActual][index].pointer].formVal,RxField[formPage[PageActual][index].pointer].write_	,RxField[formPage[PageActual][index].pointer].disable	,	RxField[formPage[PageActual][index].pointer].options}	
		
	elseif kind == "Channel" then
		parameters[index] =	{"Ch "..tostring(formPage[PageActual][index].chNum),	createChannelField,	dItem,	nil,RxField[formPage[PageActual][index].pointer].write_	,RxField[formPage[PageActual][index].pointer].disable		}	

	elseif kind == "TxtButton" then
		parameters[index] =	{"Coding by Udo Nowakowski",	createTextButton,	dItem,	"Reset-Rx","Done"}

	elseif kind == "TxtOnly" then
		parameters[index] =	{name,	createTextOnly,	RxField[formPage[PageActual][index].pointer].value,name,}
	elseif kind == "Txt" then
			parameters[index] =	{name,	createTextField, dItem,	RxField[formPage[PageActual][index].pointer].value,name,"ID"}
			if RxField[formPage[PageActual][index].pointer].index == INFO then									-- create "uid" for later identification, because name will change !
				parameters[index][6]="info"
			end		
		
	elseif kind == "page" then
		parameters[index] =	{PAGESTRG,	createTextOnly,	RxField[formPage[PageActual][index].pointer].value,name,"id"}

		
	end
  end

end


																			-- ************************************************
																			-- ***		        create new form     		*** 
																			-- ***            Input: parameters array		***
																			-- ***            Output: fields array			***
																			-- ************************************************

local function newform()

	local rxPointer
	local parameter ={}	
	fields = {}
	for i=1,20 do																		-- init fields array
		fields[i]=nil
	end
	-- print("1035 Call newform")
	form.clear()

	for index = 1, #parameters do
		parameter = parameters[index]													-- get parameters "line"
		if debug6 then print("built line",index,parameter[1]) end
		local line = form.addLine(parameter[1])											-- add empty lineinto form
	--	local line = form.addLine("X")	
		local field = parameter[2](line, parameter)										-- create field entry using corresponding method
		rxPointer= rxIndex(parameter)
		--fields[#fields + 1] = field
		fields[index] = field
--		fields[#fields + 1] =parameter[2](line, parameter)										-- create field entry using corresponding method
													-- evaluate dependencies (disable edit)
		if debug6 then print("1049 FIELDS xx building",#fields + 1,fields[#fields + 1],field,rxPointer) end
		if RxField[rxPointer].write_> 1	then											-- disabling by other lines detected
			if dishandler_get(parameter,rxPointer)	== false	then					-- so handle field disabling ; if channel mapping disabled:
				return(false)															-- return false
			end
		end	
--		if parameter[1] == txtFields[txtINFO][lan] then									-- detect line "INFO" using name
		if PageActual == 1 and index==2 then											-- detect line "INFO" using name
	--		print("954 run info ")
			fields[index]:enable(false)													-- ensure disabled
		elseif modeSim then
			-- print("1060 enable fields in sim mode")
			pcall(function() fields[index]:enable(true)	return end)						-- enable all in test / sim mode
		end
	end
--	print("FIELDS finished")
	return(true)
end


local function refreshPage()
		if newform()	then															-- call new form made from parameters array
			return(true)
		else																			-- return false caused by channel mapping disabled
			return(false)
		end

end
																			-- ************************************************
																			-- ***		        main routine paint    		*** 
																			-- ************************************************

local function paint(widget)
	local w, h = lcd.getWindowSize()

  if intro then
		local lcd_w, lcd_h = lcd.getWindowSize()
		if debug0 then print("LOAD & DISPLAY Intro",getTime()) end
		local bitmap1 = lcd.loadBitmap(bit_mp)
		if debug0 then print("LOAD finished",getTime()) end
		local bitmp_w = Bitmap.width(bitmap1)
		local bitmp_h = Bitmap.height(bitmap1)		
		local scale = bitmp_w/lcd_w
		local heightY = bitmp_h/scale
		local posY = (lcd_h-heightY)/2
		lcd.drawBitmap(0, posY, bitmap1, lcd_w, heightY)							-- >> paint image
		if bitmap1_flag ~= true then											-- check image painted before?

			bitmap1_flag = true
		end	
	
	else
	
		
		--[[

	if updateForm then																-- new page ?
		print("1101 paint: refpage")
		if refreshPage() == false then												-- channel mapping disabled				-- if not, dependencies encountert, so no channel mapping
			PageMax = 2																-- disable mapping pages
			if PageLast == 1 then													-- refresh
				PageActual =2														
			else
				PageActual = 1
			end
			refreshPage()															-- built next page
		end
	end



	updateForm = false
	uni_left = false	-- reset update flag
]]
  end
end




																			-- ************************************************
																			-- ***		        start routine 	    		*** 
																			-- ************************************************

local function create()
																					-- initialize
	print("**************************************************     create handler ********************************")

	requestInProgress 	= false														-- active request
	refreshIndex 		= 0															-- actual form field "sensor"
	modifications 		= {}														-- new setting
	repeatTimes 		= 0															-- yet not used
--	fields = {}																		-- formfield array
	pollDelay			= 0															-- yet not used 
	
	for i=1,50 do																		-- init fields array
		fields[i]=nil
	end
	introHandler = 0  																-- return to start condition
	startTime = getTime()
	uni_leftTime = startTime
	
	updateForm 		= true															-- flag new form
	PageMax 		= PageMaxValue													-- number of pages (formsheets)
	PageActual 		= 1																-- page which is displayed
	PageNext		= PageActual													-- page which should be displayed next
	PageLast		= 2																-- last shown display

	built_para()																	-- built page dependent parameters array

 	sensor={} 																		-- SPORT
	sensor = sport.getSensor({appId=APP_ID});
	sensor:idle()
	intro = true																	-- true = paint intro
	
	return {sensor=sensor, receiver=receiver, protocol=protocol, revision=revision, revtext=revtext, infotext=infotext}
end



local function turnPage(forward )
	if forward then
		PageNext = PageActual+1
		if PageNext > PageMax then
			PageNext = 1
		end
		PageLast = PageActual
		PageActual = PageNext
		updateForm = true
		refreshIndex = 0
		built_para()														-- built page dependent parameters array
		if debug0 then print("UP, goto next Page:",PageActual) end

	else
		PageNext = PageActual-1
		if PageNext == 0 then
				PageNext = PageMax
		end
		PageLast = PageActual
		PageActual = PageNext
		updateForm = true
		refreshIndex = 0
		built_para()														-- built page dependent parameters array
		if debug0 then print("DOWN, goto next Page:",PageActual) end
	end																
end																	



-- ************************************************************
-- ************   		SPORT queue handling 		    *********
-- ************************************************************

local function sportTelemetryPop(widget)
  local frame = widget.sensor:popFrame()
  if frame == nil then
    return nil, nil, nil, nil
  end
  return frame:physId(), frame:primId(), frame:appId(), frame:value()
end



local function runIntro(widget)
	
		if getTime() > startTime + SPLASHTIME then									--check within intro time, if not:
			print("END INTRO")												-- >> finish intro
			intro = false

		end
end

local function pollData(widget,dItem)								-- poll Sport for Data aquise
	-- print("!!!!!!!!!!!!   poll",dItem)
	local retVal = true
	if debug2 then print(" WAKEUP:   refreshIndex < Num Parameters, Polling ",string.format("%X",dItem),refreshIndex+1) end
	if widget.sensor:pushFrame({primId=0x30, appId=APP_ID,value= dItem }) == true then			-- send read request
		requestInProgress = true																-- activate read request loop !!!
		telemetryPopTimeout = getTime() + SPORTtimeout												-- set timeout
		pollDelay = getTime() +2/10																-- set delay until response can be expected
		if debug2 then print(" polldata:   polled successfull ",string.format("%X",dItem),APP_ID) end

	else
		if debug2 then print(" polldata:   poll returned false ",string.format("%X",dItem),APP_ID) end
		retVal = false
	end
	return retVal
end





local function wait4Data(widget,reqItem)								-- wait for SPort answere after polling; reqItem = requested DataItem
		local sportdata	= nil										
		-- print ("enter introrequest, wait for data",reqItem, getTime() , telemetryPopTimeout,telemetryPopTimeout-getTime())

		if getTime() > telemetryPopTimeout then										-- timeout ?  >> reset request
			if debug2 then print(" 1148 Wait4data:      ------------    SPort timeout  --------------") end
			requestInProgress = false	
			telemetryPopTimeout = 0
			modifications[1] = nil	
			return 999999
		else		
		--print("Fields",refreshIndex + 1,fields[refreshIndex + 1])
			frame = widget.sensor:popFrame(widget)												-- wait for frame
		  	if frame ~= nil then
				local value = frame:value()						
				local appl_id=frame:appId()						

					local fieldId
					if value % 256	== 0xFF then												-- extract dataitem(fieldID)  from package Rx "Stat" item
						if value > reqItem then													-- ditem rx Protocol/type  is 2 byte
							fieldId = value&0xFFFF
							value = math.floor(value / 256)										-- no sport2form handling, so extract here !
						end
						if debug2 then print(" 1159 Wait4data :   Frame got RawValue", string.format("%X",value),fieldId) end
					else
						fieldId = value % 256
					end

																									-- check right item & extract value
					if fieldId == reqItem then
					-- local parameter = parameters[refreshIndex + 1]								-- get corresponding form data					-- form handling
					-- if fieldId == parameter[3] then												-- received dataItem = requested item ?			-- form handling
						local value2=value
						sportdata = math.floor(value / 256)											-- extract value from package
						-- print("1170 extracted ",reqItem,sportdata)
						
				end
				

							
			end
		end	
	return sportdata

end

local function wait4items(widget,reqItem)

	local sportdata	= nil										
	--print ("enter request inprogress, wait for data",reqItem, getTime() , telemetryPopTimeout,telemetryPopTimeout-getTime())

	if getTime() > telemetryPopTimeout then										-- timeout ?  >> reset request
		if debug2 then print(" WAKEUP:      ------------    SPort timeout  --------------") end
		requestInProgress = false	
		telemetryPopTimeout = 0
		modifications[1] = nil	
		return 999999
	else		
			--print("Fields",refreshIndex + 1,fields[refreshIndex + 1])
			frame = widget.sensor:popFrame(widget)
			if frame ~= nil then
				local value = frame:value()						
				local appl_id=frame:appId()						

					local fieldId
					if value % 256	== 0xFF then												-- extracted dataitem from package Rx "Stst" item
						if value >  parameters[refreshIndex + 1][3] then						-- ditem rx Protocol/type  is 2 byte
							fieldId = value&0xFFFF
						end
						if debug2 then print(" 1260  wait4items   Frame got RawValue", string.format("%X",value),fieldId) end
					else
						fieldId = value % 256
					end
					local parameter = parameters[refreshIndex + 1]								-- get corresponding form data
					if fieldId == parameter[3] then												-- received dataItem = requested item ?
						local value2=value
						value = math.floor(value / 256)											-- extract value from package
					
						local rxPointer = rxIndex(parameter)									-- rxpointer = itemIndex
						parameters[refreshIndex + 1][4] = sport2form(value2,fieldId,parameter,rxPointer,widget)
						if debug2 then print(" 1271 wait4items   GOT", parameters[refreshIndex + 1][4]) end
								-- set parameter from value
						if value ~= nil  then 
						
							if RxField[rxPointer].write_ == 1 then													-- stage 1 enable field edit if defined
																													-- stage 2: filter dedicated cases
									
								if 		(rxPointer == Tune_enable 	or rxPointer ==   CH1_8CH9_16 or rxPointer ==  MAPonSBUS or rxPointer ==  Puls_Rate) 							-- supported by all receiver
									or	(rxPointer == FBUSMODE 		and widget.revision > 79 and widget.receiver ~= "D8")																			-- fbus avalaible rev>=80 (no D8)
									or	(widget.receiver == "D8" 	and (rxPointer == D8CPPM or rxPointer == SPORTENABLE or rxPointer == SBUSC4 or rxPointer == SBUSC8 ))					-- dedicated D8 funcs
									or	(rxPointer == CPPM 	and (widget.receiver == "Rx4/6R & Gx" or widget.receiver == "R-XSR"))																			-- cppm only XSR/ R-XSR
									or	(rxPointer == SBusNotInvert	and (widget.receiver == "D8" or widget.receiver == "Rx8Rpro" or widget.receiver == "Rx4/6R & Gx" or widget.receiver == "R-XSR"))					-- sbus not inverted
									or	(rxPointer == PWM_on_SBUS	and widget.receiver ~= "D8" )																							-- servo on sbus
									or	true
										then																																		-- enable edit mode
										if debug2 then print(" wait4items:   enable", RxField[rxPointer].name) end
										if fields[refreshIndex + 1] ~= nil then
											fields[refreshIndex + 1]:enable(true)	
										end	
								end
								
							elseif RxField[rxPointer].write_> 1 then
									local enableStatus = dishandler_get(parameter,rxPointer)
									if debug2 then print(" wait4items:   enable returned ", parameter[1],enableStatus) end
									--print("1006",refreshIndex + 1)
									fields[refreshIndex + 1]:enable(enableStatus)
							else
									if debug2 then print(" wait4items:   disable", RxField[rxPointer].name) end
									fields[refreshIndex + 1]:enable(false)					
							end
							refreshIndex = refreshIndex + 1											-- prepare to get next item
							
							if debug2 then print("\n\n\n*************************************************") end										
						end

						if (refreshIndex + 1)	<= (#parameters) and formPage[PageActual][refreshIndex + 1].pointer == RxReset then		-- filter some fields for Sport handling, here: RxReset
							refreshIndex = refreshIndex + 1	
							if debug2 then print(" wait4items:   RxReset detected") end							
						end
						--if refreshIndex == (#parameters) then  updateForm=true end			-- last item, so enable update form;  would disable all after andreas change..
						requestInProgress = false												-- active request loop "closed"
					end
				
						
			end
	end
end	


local function filterPage(pageRaw,widget)						-- built formsheet only based on supported functions of receiver type (master "pageraw" includes all possible entries in page)
	local pageX = 	{
					{pointer =	HEADER2},
					}
	local index = 1									-- >> start index / start line (1=header) 

	for counter = 1,#pageRaw do
		rxPointer = pageRaw[counter].pointer
		if debug7 then print("proof ",rxPointer,lookupRxPnt[rxPointer])	end	
		-- print(rxPointer,RxReset,rxPointer == RxReset)																							-- get item index
		if 		(rxPointer == Tune_enable or 	rxPointer == CH1_8CH9_16 or 		rxPointer ==  MAPonSBUS or 		rxPointer ==  Puls_Rate) then							-- supported by all receiver
				index = index+1
				pageX[index] = {pointer = rxPointer}
				if debug7 then print("add",lookupRxPnt[rxPointer]) end

		elseif	(rxPointer == FBUSMODE 		and widget.revision > 79 and widget.receiver ~= "D8") then																		-- fbus avalaible rev>=80 (no D8)
				index = index+1
				pageX[index] = {pointer = rxPointer}

				if debug7 then print("add",lookupRxPnt[rxPointer]) end

		elseif	rxPointer == RxReset then
				index = index+1
				pageX[index] = {pointer = rxPointer}
				--print("add",lookupRxPnt[rxPointer])
				if debug7 then print("add",lookupRxPnt[rxPointer]) end

		elseif	(receiver == "D8" 	and (rxPointer == D8CPPM or rxPointer == SPORTENABLE or rxPointer == SBUSC4 or rxPointer == SBUSC8 )) then								-- dedicated D8 funcs
				index = index+1
				pageX[index] = {pointer = rxPointer}
				if debug7 then print("add",lookupRxPnt[rxPointer]) end

		elseif	(rxPointer == CPPM 	and (widget.receiver == "X4R" or widget.receiver == "R-XSR")) then																			-- cppm only XSR/ R-XSR
				index = index+1
				pageX[index] = {pointer = rxPointer}
				if debug7 then print("add",lookupRxPnt[rxPointer]) end

		elseif	(rxPointer == SBusNotInvert	and (widget.receiver == "D8" or widget.receiver == "Rx8Rpro"or widget.receiver == "Rx4/6R & Gx"or widget.receiver == "R-XSR")) then					-- sbus not inverted
				index = index+1
				pageX[index] = {pointer = rxPointer}
				if debug7 then print("add",lookupRxPnt[rxPointer]) end

		elseif	(rxPointer == PWM_on_SBUS	and widget.receiver ~= "D8" ) then																							-- servo on sbus
				index = index+1
				pageX[index] = {pointer = rxPointer}
				if debug7 then print("add",lookupRxPnt[rxPointer]) end
		else
				if debug7 then print("NO DETECTION !") end
				--print("NO DETECTION !")
		end

	end

	return pageX

end




local function builtPage2(rx,widget)
	-- print("1431 eval page2")
	local formComPage =							-- common receiver page 2
	{										
			
		{pointer =	RxField[SBusNotInvert].index	},		--12 SBUS Inv
		{pointer =	RxField[PWM_on_SBUS].index	},			-- 3 Sbus4Value
		{pointer =	RxField[FBUSMODE].index	},  			--32 FBusMode	
		{pointer =	RxField[CPPM].index	},  				--34 CPPM	(X4R & R XSR only)													
		{pointer =	RxField[RxReset].index}	  				--25 Button Reset																	--   flash RX
  	}

	local formD8Page =							-- D series receiver
	{
		{pointer =	HEADER2},	
		{pointer =	RxField[SBusNotInvert].index	},		--12 SBUS Inv
		{pointer =	RxField[D8CPPM].index	},				
		{pointer =	RxField[SPORTENABLE].index	},			
		{pointer =	RxField[SBUSC4].index	},  		
		{pointer =	RxField[SBUSC8].index},	  				
		{pointer =	RxField[RxReset].index}	  			
	}

	
	if rx == "D8" then
		formPage[2] = formD8Page				-- "dedicated" D8 2nd page
		--print("D8 paras recognized")
	else
		formPage[2] = filterPage(formComPage,widget)				-- typical page
		--print("common paras recognized")
	end
	
end




																			-- ************************************************
																			-- ***		     "background" routine 	   		*** 
																			-- ************************************************

local function wakeup(widget)
	local tmp	
	local revtxt = "n/a"
	if intro then 

		runIntro(widget)

	else

	--	if RunOnStart and not requestInProgress then
		

		if modeSim and introHandler < 10 then 					-- simulate read header/intro data
			print("1477 simulate data")
			widget.receiver = RecLookup(9)
			widget.protocol = protoLookup(1)
			widget.revision = 80
			revtxt = tostring(widget.revision)	
			widget.infotext = widget.protocol 	.. "   rev:"..revtxt

			if PageActual == 1 then
				parameters[2][1] = "RX:       "..widget.receiver		-- set new "name" at infoline
			end
			RxField[INFO].name		= "RX:       "..widget.receiver
			RxField[INFO].formVal 	= widget.infotext						-- set new textvalue at infoline
			-- print("1485 **************    eval Page2")
			builtPage2(widget.receiver,widget)
			newform()	


			introHandler = 99
		elseif not(modeSim) and introHandler < 10 then									-- get header / intro data: rx Type, protocol & FW revision
																										-- get header infos on start
			if 	introHandler == 0 then								-- poll receiver Info
					-- print("1221 poll receiver type")
			
					local retVal= pollData(widget,DIT_RECEIVER)
					if retVal then
						-- print("SPORT poll OK")
						introHandler = 1							-- next step
					else
						-- print("no SPORT poll")
						introHandler = 9							-- 9= error exception handling
					end


			elseif 	introHandler == 1 then							-- wait for receiver info
					tmp = wait4Data(widget,DIT_RECEIVER)
					if tmp ~= nil then
						if tmp ~= 999999 then
							widget.receiver = RecLookup(tmp)
							--widget.receiver = RecLookup(1)
							--print("1248 got receiver type",tmp,receiver)
							introHandler = 2
						else
							--print("1251 got receiver type TIMEOUT",tmp)
							introHandler = 0						-- now Rx answere, so please retry
						end
					end
					
			elseif	introHandler == 2 then							-- poll protocol info
					--print("1257 poll protocol")
					local retVal= pollData(widget,DIT_PROTOCOL)
					if retVal then
						--print("SPORT poll OK")
						introHandler = 3
					else
						--print("no SPORT poll")
						introHandler = 9
					end

			elseif 	introHandler == 3 then							-- wait for protocol info
					tmp = wait4Data(widget,DIT_PROTOCOL)
					if tmp == 999999 then

						--print("1226 got Protocol TIMEOUT",tmp)
						introHandler = 9
					elseif tmp ~= nil then
						--print("1270 got Protocol",tmp)
						widget.protocol = protoLookup(tmp)
						introHandler = 4
					end

			elseif 	introHandler == 4 then							-- poll revision info
					--print("1278 poll Revision")
					local retVal= pollData(widget,DIT_REVISION)
					if retVal then
						--print("SPORT poll OK")
						introHandler = 5
					else
						--print("no SPORT poll")
						introHandler = 9
					end
			elseif 	introHandler == 5 then							-- wait for revision info
					widget.revision = wait4Data(widget,DIT_REVISION)

					if widget.revision ~= nil then
						--local revtxt
						if widget.revision ~= 999999 then
							if widget.revision > 0 then
								revtxt = tostring(widget.revision)			-- got Rev#
						--	else
						--		revtxt = "n/a"						-- returnValue = 0, so older FW  (<80), so no data	; (timeout)
							end
						--else
					--		revtxt = "n/a"						-- returnValue = 0, so older FW  (<80), so no data	; (timeout)				
						end
						--print("1398 got rev",widget.revision,widget.revtxt)
						widget.infotext = widget.protocol 	.. "   rev:"..revtxt

						if PageActual == 1 then
							parameters[2][1] = "RX:       "..widget.receiver			-- set new "name" at infoline
						end

						RxField[INFO].name		= "RX:       "..widget.receiver
						RxField[INFO].formVal 	= widget.infotext						-- set new textvalue at infoline
						--print("**************   1400 header infotext",widget.infotext)
						--print("**************    eval Page2")
			
		
						introHandler = 6							-- exit reading intro data
					end
			elseif introHandler == 6 then							-- data finished, await end of intro
				if not(intro) then
					builtPage2(widget.receiver,widget)		
			
					lcd.invalidate()

					form.clear()
					newform()	
					introHandler = 99
				end
			elseif introHandler == 9 then							-- Problem !
					-- exception handling, no values read from Rx
					RxField[INFO].formVal = "ERROR, NO DATA !!"
					lcd.invalidate()
					form.clear()
					newform()									-- generate Form with new intro values
			end

		
		elseif not(modeSim) then																						-- header infos available, so proceed:
			lcd.invalidate()	 
				if requestInProgress then	
					if parameters[refreshIndex + 1] == 2 and PageActual == 1 then					-- infoline, data was received during intro, so jump..
						refreshIndex = refreshIndex + 1	
					else	
						
					--	local retVal = wait4items(widget,reqItem)
						
									-- request active ?
						frame = widget.sensor:popFrame(widget)
						if frame ~= nil then
							local value = frame:value()						
							local appl_id=frame:appId()						

								local fieldId
								if value % 256	== 0xFF then												-- extracted dataitem from package Rx "Stst" item
									if debug8 then print("1665 Wakeup: refIndex, value, prot/Type para",refreshIndex + 1, value, parameters[refreshIndex + 1][3] ) end
									if value >  parameters[refreshIndex + 1][3] then						-- ditem rx Protocol/type  is 2 byte
										fieldId = value&0xFFFF
									end
									if debug8 then print(" 1665 WAKEUP:   Frame got RawValue", string.format("%X",value),fieldId) end
								else
									fieldId = value % 256
								end
								local parameter = parameters[refreshIndex + 1]								-- get corresponding form data
								if fieldId == parameter[3] then												-- received dataItem = requested item ?
									local value2=value
									value = math.floor(value / 256)											-- extract value from package
								
									local rxPointer = rxIndex(parameter)
									parameters[refreshIndex + 1][4] = sport2form(value2,fieldId,parameter,rxPointer,widget)
									if debug2 then print(" WAKEUP:   1552 could read", parameters[refreshIndex + 1][1],parameters[refreshIndex + 1][4],value) end			-- print lineName & value
									-- set parameter from value
									if value ~= nil  then 
									
										if RxField[rxPointer].write_ == 1 then													-- stage 1 enable field edit if defined
																																						-- enable edit mode
												if debug2 then print(" WAKEUP:   enable", RxField[rxPointer].name) end
												if fields[refreshIndex + 1] ~= nil then
													fields[refreshIndex + 1]:enable(true)	
												end	
											
										elseif RxField[rxPointer].write_> 1 then
												local enableStatus = dishandler_get(parameter,rxPointer)
												if debug2 then print(" WAKEUP:   enable returned ", parameter[1],enableStatus) end
												--print("1006",refreshIndex + 1)
												fields[refreshIndex + 1]:enable(enableStatus)
										else
												if debug2 then print(" WAKEUP:   disable", RxField[rxPointer].name) end
												fields[refreshIndex + 1]:enable(false)					
										end
										refreshIndex = refreshIndex + 1											-- prepare to get next item
										
										if debug2 then print("\n\n\n*************************************************") end										
									end

									if (refreshIndex + 1)	<= (#parameters) and formPage[PageActual][refreshIndex + 1].pointer == RxReset then		-- filter some fields for Sport handling, here: RxReset
										refreshIndex = refreshIndex + 1	
										if debug2 then print(" WAKEUP:   RxReset detected") end							
									end
									--if refreshIndex == (#parameters) then  updateForm=true end			-- last item, so enable update form;  would disable all after andreas change..
									requestInProgress = false												-- active request loop "closed"
								end
							
						else
								if getTime() > telemetryPopTimeout then										-- timeout ?  >> reset request
									if debug2 then print(" WAKEUP:      ------------    SPort timeout  --------------") end
									requestInProgress = false	
									telemetryPopTimeout = 0
									modifications[1] = nil	
									refreshIndex = refreshIndex + 1				-- next field
									if refreshIndex == (#parameters) then  updateForm=true end
								end										
						end
						
					end	

				elseif resetFlag then																	-- RxReset encountered

					-- disable fields here
						

						for i=1,#parameters do
							
							if fields[i] ~= nil then 
								--print("reset Field",i,fields[i][1]," ","#fields:",#parameters)
								if pcall (function()  fields[i]:enable(false)  end) then 
									if debug9 then print("reset // field enabled:",i) end
								else
									if debug9 then print("reset // field enable @index i failed:",i) end
								end
							end
						end
						if getTime() > nextWrite then
							if Rx_Reset[resetcounter] ~= CHAN_Mapping then
								local value = RxField[Rx_Reset[resetcounter]].SPortdefault
								if debug2 then print("pushreset",resetcounter,APP_ID,string.format("%x",value)) end
								widget.sensor:pushFrame({primId=0x31, appId=APP_ID, value=value})
								nextWrite = getTime() + writeInterval
								resetcounter = resetcounter+1
							else																			-- channel map handler
								for i = 0, 15 do
									chMap[i+1] = i+1														-- Sport 0..15 // formValues & index: 1..16 
									local value =  i*65536 + i*256 + 0xE9  									-- workaround missing bit32lib bor: Byte3..1   value:channel:item
										nextWrite = getTime() + writeInterval
										widget.sensor:pushFrame({primId=0x31, appId=APP_ID, value=value})				
										if debug2 then print("pushreset Channel",i,string.format("%x",value)) end
																							-- don't flood Sport:
									::loopCh::
										if getTime() > nextWrite then
											goto breakCh
										else
											goto loopCh
										end
									::breakCh::
								end	
								resetcounter = resetcounter+1												-- reset channel mapping finished
							end
							
							if resetcounter > #Rx_Reset then												-- reset finished ?
								resetcounter = 1															-- >> reset counter
								resetFlag = false															-- >> reset flag
								updateForm = true															-- initiate page refresh
								refreshIndex = 0
								built_para()
								if debug2 then print("reset finished success") end
							end
						end
					
				else																			-- no request & no startup sequence in progress determined
						if #modifications > 0 then																		-- maybe new data to be written / "write request" ?
							local j = 0
							for j = 1,#modifications do
								widget.sensor:pushFrame({primId=0x31, appId=APP_ID,value=modifications[j][2]})				-- send data
							--	print("1736 write item",j)
							--	print("1737 write value",string.format("%x",modifications[j][2]))
							--	print("1737 write value",modifications[j][2])											-- error << nil ??
								modifications[j] = nil
							end
							refreshIndex = 0																			-- reset index so new "read all" initiated
							requestInProgress = false																	-- reset request status
																				-- reset mod
							--print("1158 write",string.format("%x",modifications[1][2]))
							--print("1660 write",string.format("%x",value))

						elseif refreshIndex < (#parameters ) then														-- no write request, maybe read request ?
							local dItem
							local parameter = parameters[refreshIndex + 1]
							if parameter[1] == PAGESTRG  or (PageActual == 1 and refreshIndex == 1 ) then				-- exclude header & info lines: nothing todo
								--	refreshIndex = 1																	-- jmp to second entry
								refreshIndex = refreshIndex +1
							else
								dItem = parameter[3]
								if dItem == RxField[CHAN_Mapping].d_item then
									if debug2 then print(" WAKEUP:   channelrequest",dItem) end
									dItem = dItem + (formPage[PageActual][refreshIndex + 1].chNum -1)*256
								end
								if debug2 then print(" WAKEUP:   refreshIndex < Num Parameters, Polling ",string.format("%X",dItem),refreshIndex+1) end
								if widget.sensor:pushFrame({primId=0x30, appId=APP_ID,value= dItem }) == true then			-- send read request
									requestInProgress = true																-- activate read request loop !!!
									telemetryPopTimeout = getTime() + SPORTtimeout												-- set timeout
									pollDelay = getTime() +2/10																-- set delay until response can be expected
									if debug2 then print(" WAKEUP:   polled successfull ",string.format("%X",dItem)) end
								else
									if debug2 then print(" WAKEUP:   poll returned false ",string.format("%X",dItem)) end
								end
							end
						elseif refreshIndex == #parameters and  updateForm	then											-- all items on page were read, so update page if new page was called
							if debug2 then print(" WAKEUP:   ++++++++++++++++     paint new page  ++++++++++++++++",PageActual,refreshIndex ) end
							lcd.invalidate()
						end

				end
		else			-- modesim in std wakeup loop
			--print("1722 wakeup modesim ")
		end

		if updateForm then																-- new page ?
			--print("1101 paint: refpage")
			if refreshPage() == false then												-- channel mapping disabled				-- if not, dependencies encountert, so no channel mapping
				PageMax = 2																-- disable mapping pages
				if PageLast == 1 then													-- refresh
					PageActual =2														
				else
					PageActual = 1
				end
				refreshPage()															-- built next page
			end
		end



		updateForm = false
		uni_left = false	-- reset update flag
	end
end



	
local function event(widget, category, value, x, y,sensor)
 print("Event received:", category, value, x, y)
	
	if category == EVT_KEY and value == KEY_EXIT_BREAK then
	--[[			updateForm = false
				intro = true
				uni_left = true
				uni_leftTime = getTime()
				print("BREAK-A",updateForm,intro,uni_left,uni_leftTime)]]
				--sensor:idle(false)
			--widget.sensor:idle(false)
			
			
	elseif category == 0 and value == 132 then		-- lng RTN´

			--[[	updateForm = false
				intro = true
				unileft = true
				uni_leftTime = getTime()
				print("BREAK-B",updateForm,intro,uni_left,uni_leftTime)]]
				--sensor:idle(false)
				--return false
			--widget.sensor:idle(false)

	else
		--print("pg up:",KEY_PAGE_UP ,"down:",KEY_PAGE_DOWN,"eval:", not (requestInProgress or (#modifications > 0) or  resetFlag), "value:",value )
		local eval =  not (requestInProgress or (#modifications > 0) or  resetFlag) or modeSim
		--print("check?",eval)
		if eval then --ACTION
			--print("Eval page")
			if refreshIndex >= #parameters or modeSim then										--	prevent Sport handling disruption
				--if value == KEY_PAGE_UP or value == 96 then							--  page up button	---ACTION TOGGLE
				if value == KEY_PAGE_UP  then	
					--print(".<<<<<<<< BACK")
					local forward = false
					-- local forward = false
					turnPage(forward )
				elseif value == KEY_PAGE_DOWN then	
					local forward  = true
					--forward = true
					turnPage(forward )
					--print(">>>>>>>> FWD")
				end
			end																	--end ACTION
		end			--]]
	end
	return
--	return false
end




local icon = lcd.loadMask("main.png")



local function init()
 system.registerSystemTool({name=name, icon=icon, create=create, wakeup=wakeup, event=event ,paint = paint})
end

return {init=init}