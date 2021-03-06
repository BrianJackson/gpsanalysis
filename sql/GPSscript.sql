USE [uspsmdd]
GO
/****** Object:  UserDefinedFunction [dbo].[CalcBearing]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================

-- Description: Returns the angle in degrees between 2 GPS coordinates
-- https://www.igismap.com/map-tool/bearing-angle
/*
The angle follows the convention that angles to the west are -1 to -180 and the east are 1 to 180.  This function is used
to populate tmpGPSBearing.
*/  
-- =============================================
CREATE   FUNCTION [dbo].[CalcBearing]
(
     @lat1 Decimal(14,8)
	,@lat2 Decimal(14,8)
	,@lon1 Decimal(14,8)
	,@lon2 Decimal(14,8)
)
RETURNS float
AS
BEGIN
	DECLARE @bearing float

	SELECT @bearing =
     CASE WHEN (@lat2-@lat1) = 0 AND (@lon2-@lon1) = 0
			THEN 0
		ELSE
			ATN2(
				COS(@lat2) * SIN(@lon2-@lon1) 
			,
				COS(@lat1) * SIN(@lat2) - SIN(@lat1) * COS(@lat2) * COS(@lon2-@lon1)
			) * (180/3.14159265359)
		END 
	RETURN @bearing
END
GO
/****** Object:  UserDefinedFunction [dbo].[CalcBearing2]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description: Returns the angle in degrees between 2 GPS coordinates
-- https://www.igismap.com/map-tool/bearing-angle
-- Bearings range from 0 to 360.  This function is used to populate tmpGPSBearing360.   The 360 degree
-- representation makes calculating reverse simpler as the difference in 2 bearings would be 180 with some
-- margin such as 5 degrees to the left or right.
-- =============================================
CREATE  FUNCTION [dbo].[CalcBearing2]
(
     @lat1 Decimal(14,8)
	,@lat2 Decimal(14,8)
	,@lon1 Decimal(14,8)
	,@lon2 Decimal(14,8)
)
RETURNS float
AS
BEGIN
	DECLARE @bearing float

	SELECT @bearing =
     CASE WHEN (@lat2-@lat1) = 0 AND (@lon2-@lon1) = 0
			THEN 0
		ELSE
			ATN2(
				COS(@lat2) * SIN(@lon2-@lon1) 
			,
				COS(@lat1) * SIN(@lat2) - SIN(@lat1) * COS(@lat2) * COS(@lon2-@lon1)
			) * (180/3.14159265359)
		END 

	-- West headings range from -180 to -1.  This converts this to 180 to 359
	IF @bearing < 0  
		SELECT @bearing = @bearing + 360
	

	RETURN @bearing
END
GO
/****** Object:  UserDefinedFunction [dbo].[ToDecDegrees]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description: Convert Degress Minutes.M to Decimal Degrees
-- The GPSGLL records represent coordinates as DDMM.mmmmm.  The radian calculations CalcBearing and CalcBearing2 
-- require decimal degrees so this function performs that conversation.
-- =============================================
CREATE   FUNCTION [dbo].[ToDecDegrees]
(
	@DMM decimal(14,8)
	, @Direction char
)
RETURNS decimal(14,8)
AS
BEGIN
    -- Declare the return variable here
    DECLARE @DecDegrees decimal(14,8)

    SELECT @DecDegrees = 
	CAST(@DMM/100 as int) + ( @DMM - CAST(@DMM/100 as int) * 100) / 60.0 
   
	-- Return the result of the function
	IF @Direction = 'W' OR @Direction = 'S' 
		SELECT @DecDegrees = -1 * @DecDegrees

    RETURN @DecDegrees
END
GO
/****** Object:  Table [dbo].[gpsraw]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[gpsraw](
	[TimeStamp] [nvarchar](max) NULL,
	[Value] [nvarchar](max) NULL,
	[recordtype] [nvarchar](max) NULL,
	[latitude] [decimal](10, 5) NULL,
	[dir_latitude] [nvarchar](max) NULL,
	[longitude] [decimal](10, 5) NULL,
	[dir_longitude] [nvarchar](max) NULL,
	[utc_position] [decimal](15, 5) NULL,
	[is_valid] [nvarchar](max) NULL,
	[mode] [nvarchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[GPSVectors]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE   VIEW [dbo].[GPSVectors] AS
-- This view uses common table expressions and the ToDecDegrees scalar function to
-- take the raw GPSGLL output, convert the coordinates and return the vectors
-- on a single row so that the bearing can be calculated for each pair of coordinates
-- i.e. [point1, point2], [point2, point3], [point3, point4], etc.
WITH Prev_PointCTE (positionnum, latitude, longitude)
AS
(
SELECT ROW_NUMBER() OVER(ORDER BY [timestamp] asc) positionnum
	   , dbo.ToDecDegrees(latitude,dir_latitude) latitude
	   , dbo.ToDecDegrees(longitude, dir_longitude) longitude
FROM gpsraw
)
, PointCTE (positionnum, latitude, longitude, positiontime)
AS
(
SELECT ROW_NUMBER() OVER(ORDER BY [timestamp] asc) positionnum
	   , dbo.ToDecDegrees(latitude,dir_latitude) latitude
	   , dbo.ToDecDegrees(longitude, dir_longitude) longitude
	   , CAST([timestamp] as datetime) positiontime
FROM gpsraw 
)
SELECT p.positionnum, pp.latitude lat1, pp.longitude lon1, p.latitude lat2, p.longitude lon2,  p.positiontime
FROM PointCTE p
JOIN Prev_PointCTE pp ON pp.positionnum = p.positionnum - 1


GO
/****** Object:  Table [dbo].[tmpGPSBearing360]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tmpGPSBearing360](
	[positionnum] [bigint] NULL,
	[lat1] [decimal](14, 8) NULL,
	[lon1] [decimal](14, 8) NULL,
	[lat2] [decimal](14, 8) NULL,
	[lon2] [decimal](14, 8) NULL,
	[positiontime] [datetime] NULL,
	[bearing] [float] NULL
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[GPSTurns2]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE     VIEW [dbo].[GPSTurns2] AS
--select *, [dbo].[CalcBearing2](lat1, lat2, lon1,lon2) bearing INTO tmpGPSBearing360 from [dbo].[GPSVectors]
WITH Prev_PointCTE (positionnum, positiontime, bearing)
AS
(
SELECT  positionnum
	   , positiontime
	   , bearing
FROM tmpGPSBearing360
)
, PointCTE (positionnum, positiontime, bearing)
AS
(
SELECT positionnum
	   , positiontime
	   , bearing
FROM tmpGPSBearing360
)
SELECT pp.positionnum pnum1, p.positionnum pnum2, p.positiontime, pp.bearing bearing1, p.bearing bearing2 
FROM PointCTE p
JOIN Prev_PointCTE pp ON  p.positionnum = pp.positionnum + 1


GO
/****** Object:  UserDefinedFunction [dbo].[GPSBearing360]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- *** DO NOT USE ***
-- Description:	Returns the decimal lat, long and bearing in degrees from 0 to 360
-- This function is intended to remove the need for the tables tmpGPSBearing or tmpGPSBearing360
-- however the output of the table function excludes rows that are found in the select statement.
-- 
-- Until this can be resolved, the tmpGPSBearing360 table is used by the GPSTurns2 View instead of this TVF
-- =============================================
CREATE FUNCTION [dbo].[GPSBearing360]
(	
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT *, [dbo].[CalcBearing2](lat1, lat2, lon1,lon2) bearing from [dbo].[GPSVectors]
)
GO
/****** Object:  View [dbo].[ReverseEvents]    Script Date: 7/25/2019 8:50:53 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[ReverseEvents] AS
/*
https://www.igismap.com/formula-to-find-bearing-or-heading-angle-between-two-points-latitude-longitude/
https://www.igismap.com/map-tool/bearing-angle

This view queries the GPSTurns2 view which has the bearings of each vector (bearing1 and bearing2) in degrees (1-360) 
Taking the difference in bearing indicates the change in direction
For example if bearing1 = 1 (almost due north) and bearing2 = 91 (almost due east), that represents a 90 degree right turn.  
If bearing1 = 1 and bearing2 = 181, that represents a 180 degree turn.   This usually represents a reversal in a vehicle.  Note
that the GPS data includes walking.

When bearing2 = 0 this almost always represents a stationary point  (lat1 = lat2, long1 = long2)
*/

select *, bearing1 - bearing2 as delta 
, CASE	WHEN bearing2 = 0 THEN'stopped'
		WHEN bearing1 = 0 THEN 'straight'
		WHEN bearing1 - bearing2 between 170 and 190 THEN 'reverse'
		WHEN bearing1 - bearing2 between -190 and -170 THEN 'reverse'
		WHEN ABS(bearing1 - bearing2) between 0.0001 and 20 THEN 'straight'		
		ELSE 'turn'
   END as navevent	
  					
FROM GPSTurns2
WHERE 1=1
AND (bearing1-bearing2 between -170 and -190
	OR bearing1-bearing2 between 170 and 190
	)
AND bearing2 <> 0 



GO
