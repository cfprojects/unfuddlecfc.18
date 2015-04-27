<cfparam name="url.project_id" type="any" default="0" />


<cfdirectory action="list" directory="#ExpandPath('./projects/')#" name="projectDirs" recurse="true" type="dir" />

<cfquery name="projectDirs" dbtype="query">
	SELECT 	*
	FROM 	projectDirs
	WHERE 	directory not like '%.svn%'
	AND 	name not like '%.svn%'
	<cfif url.project_id neq 0>
	AND 	name = '#url.project_id#'
	</cfif>

</cfquery>


<cfloop query="projectDirs">
	<cfset project_id = name />
	<cfset projectDirectory = ExpandPath('./projects/#name#') />
	<cfset logfilepath = projectDirectory & "/log.txt" />
	
	<cfif not FileExists(logfilepath)>
		<cfset fileWrite(logfilepath, "") />
	
	</cfif>
	<cfset logFile = FileOpen(logfilepath,"write") />

	
	<cfoutput><h1>Project: #project_id#</h1></cfoutput>
	<p>Processing Credentials</p>
	<cfset FileWriteLine(logfile, "#now()#, Starting Backup Process") />
	
	<cfif not FileExists(projectDirectory & "/credentials.cfm")>
		<cfoutput><p>Credentials Missing for #name#</p></cfoutput>
		<cfset FileWriteLine(logfile, "#now()#, Credentials Missing") />
		<cfset FileWriteLine(logfile, "#now()#, Ending Backup Process") />
		<cfset fileClose(logFile) />	
		<cfbreak />		
	</cfif>

	<cfset credentials = FileRead(projectDirectory & "/credentials.cfm") />
	<cfset credentials = ReplaceNoCase(credentials, "<cfabort>","", "ONCE" ) />
	<cfwddx action="wddx2cfml" input="#credentials#" output="creds" />
	
	<cfloop collection="#creds#" item="field">
		<cfset creds[field] = Decrypt(creds[field],AESSecret, "AES", "HEX")>
	</cfloop>
	
	<cfset unfuddle =  CreateObject("component", "unfuddle.cfc.unfuddle").init(username=creds.username, password=creds.password, unfuddleurl=creds.unfuddleurl, debug=false) />	

	<cfset backupInProgressFile = projectDirectory & "/backupInProgressFile.xml" />

	<cfdirectory directory="#projectDirectory#" action="list" filter="*.gz" name="backupList" />
	
	
	<cfquery name="backupTest" dbtype="query">
		SELECT *
		FROM backuplist
		where datelastmodified > <cfqueryparam cfsqltype="CF_SQL_TIMESTAMP" value="#DateAdd('d', -7, now())#">
	</cfquery>
	
	<cfif backupTest.recordCount gt 0>
		<p>Recent Backup Exist</p>
		<cfset FileWriteLine(logfile, "#now()#, Recent Backup Exist") />
		<cfset FileWriteLine(logfile, "#now()#, Ending Backup Process") />
		<cfset fileClose(logFile) />	
		<cfbreak />
	</cfif> 

	<!--- If a backup isn't pending, request one.' --->
	<cfif not FileExists(backupInProgressFile)>
		<p>Requesting Backup</p>
		<cfset backupRequest=unfuddle.CreateBackup(project_id) />
		<cfset FileWrite(backupInProgressFile, backupRequest.id) />
		<cfset FileWriteLine(logfile, "#now()#, Requesting Backup.") />
		<cfset FileWriteLine(logfile, "#now()#, Ending Backup Process") />
		<cfset fileClose(logFile) />	
		<cfbreak />
	</cfif>

	<p>Retrieving data about backup in progress</p>
	<cfset backupID = FileRead(backupInProgressFile) />
	
	<cfset backup= unfuddle.getBackup(project_id,backupID) />
	
	
	
	<cfif backup.processed>
		<p>Downloading Backup.</p>
		<cfset unfuddle.downloadBackup(project_id,backupID, projectDirectory) />
		<p>Downloading Complete</p>
		<p>Clearing in Progress flag</p>
		<cfset FileDelete(backupInProgressFile) />
		
		<cfset FileWriteLine(logfile, "#now()#, Backup downloaded.") />
		<cfset FileWriteLine(logfile, "#now()#, Ending Backup Process") />
		<cfset fileClose(logFile) />	
		
		<cfif structKeyExists(creds, "email")>
			<cfmail to="#creds.email#" from="#creds.email#" subject="Unfuddle Project backup has been downloaded." type="HTML">
				<p>Project #project_id# has been backed-up and retrieved.</p>
			</cfmail>
		</cfif> 
		
		 
	<cfelse>
		<p>Backup has not been processed yet.</p>
		<cfset FileWriteLine(logfile, "#now()#, Backup has not been processed yet..") />
		<cfset FileWriteLine(logfile, "#now()#, Ending Backup Process") />
		<cfset fileClose(logFile) />	
	</cfif>

	
</cfloop>


<cfschedule 
    action = "update"
    task = "Unfuddle Backup #application.applicationname#"
    interval = "120"
    operation = "HTTPRequest"
    requestTimeOut = "600"
    resolveURL = "no"
    startDate = "#dateFormat(now())#"
    startTime = "#timeFormat(now())#"
    url = "http://#cgi.server_name#/#cgi.script_name#">













