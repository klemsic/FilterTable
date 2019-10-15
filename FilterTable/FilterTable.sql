CREATE TYPE [dbo].[FilterTable] AS TABLE
(
	[Column] NVARCHAR(500) NOT NULL,
	[Sort] BIT NULL, -- NULL = No orde by, 1 = asc, 0 = desc
	[Filter] NVARCHAR(500) NULL,
	[FilterType] NVARCHAR(100) NOT NULL	CHECK ([FilterType] IN ('contains',
									'notContains',
									'equals',
									'notEquals',
									'startsWith',
									'endsWith',
									'more',
									'moreEquals',
									'less',
									'lessEquals'))
									DEFAULT N'contains'
)
