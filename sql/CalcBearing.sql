-- ======================================================
-- Create Scalar Function Template for Azure SQL Database
-- ======================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      <Author, , Name>
-- Create Date: <Create Date, , >
-- Description: <Description, , >
-- =============================================
CREATE OR ALTER FUNCTION CalcBearing
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
				CAST(COS(@lat1) * SIN(@lat2) - SIN(@lat1) * COS(@lat2) * COS(@lon2-@lon1) as float)
			,
				CAST(SIN(@lon2-@lon1) * COS(@lat2) as float)
			)
		END 
	RETURN @bearing
END
GO

