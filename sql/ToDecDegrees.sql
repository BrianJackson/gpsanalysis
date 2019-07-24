/****** Object:  UserDefinedFunction [dbo].[ToDecDegrees]    Script Date: 7/24/2019 2:04:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description: Convert Degress Minutes.M to Decimal Degrees
-- =============================================
ALTER   FUNCTION [dbo].[ToDecDegrees]
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
