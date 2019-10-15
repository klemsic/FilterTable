CREATE PROCEDURE [dbo].[P_FilterTable]
	@TableName NVARCHAR(500),
	@FilterTable [dbo].[FilterTable] NULL READONLY,
	@PageIndex INT = 0,
	@PageSize INT  = 2147483647,
	@TotalRows INT OUTPUT
AS
BEGIN
	------------------------------ Prepare where clause. ------------------------------
	DECLARE @WhereClause AS NVARCHAR(MAX);
	SELECT 'AND ' + [Column] + CASE [FilterType]	WHEN 'contains' THEN ' LIKE ''%' + [Filter] + '%'''
													WHEN 'notContains' THEN ' NOT LIKE ''%' + REPLACE([Filter],'''','''''') + '%'''
													WHEN 'equals' THEN ' = ''' + REPLACE([Filter],'''','''''') + ''''
													WHEN 'notEquals' THEN ' != ''' + REPLACE([Filter],'''','''''') + ''''
													WHEN 'startsWith' THEN ' LIKE ''' + REPLACE([Filter],'''','''''') + '%'''
													WHEN 'endsWith' THEN ' LIKE ''%' + REPLACE([Filter],'''','''''') + ''''
													WHEN 'more' THEN ' > ''' + REPLACE([Filter],'''','''''') + ''''
													WHEN 'moreEquals' THEN ' >= ''' + REPLACE([Filter],'''','''''') + ''''
													WHEN 'less' THEN ' < ''' + REPLACE([Filter],'''','''''') + ''''
													WHEN 'lessEquals' THEN ' <= ''' + REPLACE([Filter],'''','''''') + ''''
													END AS [SubQuery]
	INTO #WhereClause
	FROM @FilterTable
	WHERE [Filter] IS NOT NULL OR [Filter] != ''

	SET @WhereClause = (SELECT ' ' + [SubQuery] FROM #WhereClause FOR XML PATH, TYPE).value(N'.[1]', N'nvarchar(max)')
	DROP TABLE #WhereClause


	------------------------------ Prepare order by clause. ------------------------------
	DECLARE @OrderByClause AS NVARCHAR(MAX);
	SELECT [Column] + CASE [Sort]	WHEN 1 THEN ' asc'
									WHEN 0 THEN ' desc'
									END AS [SubQuery]
	INTO #OrderByClause
	FROM @FilterTable
	WHERE [Sort] IS NOT NULL

	SET @OrderByClause = STUFF((SELECT DISTINCT ', ' + [SubQuery] FROM #OrderByClause FOR XML PATH('')),1,1,'')
	DROP TABLE #OrderByClause


	------------------------------ Filters the whole table. ------------------------------
	DECLARE @IndexColumn AS NVARCHAR(255)
	DECLARE @FilterSelect AS NVARCHAR(MAX)
	SET @IndexColumn = CAST(NEWID() AS nvarchar(255))
	SET @FilterSelect =	'SELECT ROW_NUMBER() OVER (Order by (SELECT 1)) AS [' + @IndexColumn + '], * INTO ##Data FROM ' + QUOTENAME(@TableName) + ' ' +
						'WHERE 1 = 1 ' + ISNULL(@WhereClause,'') + ' ' +
						'ORDER BY ' + ISNULL(@OrderByClause,1)

	EXEC(@FilterSelect)


	------------------------------ Pagging ------------------------------
	SET @TotalRows = @@ROWCOUNT
	DECLARE @PageLowerBound AS INT
	DECLARE @PageUpperBound AS INT
	DECLARE @LastPage AS INT

	-- Set last page.
	SET @LastPage = @TotalRows / @PageSize
	IF (@TotalRows % @PageSize) > 0 
		SET @LastPage = @LastPage + 1

	-- Set bounds.
	SET @PageLowerBound = (@PageSize * @PageIndex) +1
	SET @PageUpperBound = @PageLowerBound + (@PageSize - 1)

	-- Deletes records that are not on the page.
	DECLARE @PaggingDelete AS NVARCHAR(MAX)
	SET @PaggingDelete = 'DELETE FROM ##Data WHERE [' + @IndexColumn + '] NOT BETWEEN ' + CAST(@PageLowerBound AS NVARCHAR(100)) + ' AND ' + CAST(@PageUpperBound AS nvarchar(100))
	EXEC(@PaggingDelete)

	-- Drop index for sorting records.
	DECLARE @IndexDrop AS NVARCHAR(MAX)
	SET @IndexDrop = 'ALTER TABLE ##Data DROP COLUMN [' + @IndexColumn + ']'
	EXEC(@IndexDrop)


	------------------------------ Finally ------------------------------
	DECLARE @SelectPage AS NVARCHAR(MAX)
	SET @SelectPage = 'SELECT * FROM ##Data ORDER BY ' + ISNULL(@OrderByClause,1)
	EXEC(@SelectPage)

	DROP TABLE ##Data
END
