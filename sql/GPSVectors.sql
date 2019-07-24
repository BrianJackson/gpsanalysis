
CREATE OR ALTER VIEW GPSVectors AS
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
SELECT p.positionnum, p.latitude lat2, p.longitude lon2, pp.latitude lat1, pp.longitude lon1, p.positiontime
FROM PointCTE p
JOIN Prev_PointCTE pp ON pp.positionnum = p.positionnum - 1


