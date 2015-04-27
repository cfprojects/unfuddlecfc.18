<!---
Copyright 2008 Terrence Ryan
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--->
<cfcomponent>

	<cffunction name="init" output="false" access="public"  returntype="any" hint="Psuedo constructor that allows us to play our object games." >
		<cfargument name="unfuddleUrl" type="string" required="yes" hint="The Unfuddle URL to use." />
		<cfargument name="username" type="string" required="yes" hint="The Unfuddle Username to use." />
		<cfargument name="password" type="string" required="yes" hint="The Unfuddle Password to use." />
		<cfargument name="debug" type="boolean" default="false" hint="Whether or not to output debugging information to cf debugging, and collects the raw xml in the temp directory. " />
		<cfargument name="timeout" type="numeric" default="5" hint="The timeout on http calls." />
		<cfargument name="apiversion" type="string" default="v1" hint="The version of the api to call." />
		<cfargument name="curlPath" type="string" default="c:\curl\curl.exe" hint="The path to the curl.exe" />
		
		<cfset variables.unfuddleUrl = arguments.unfuddleUrl />
		<cfset variables.username = arguments.username />
		<cfset variables.password = arguments.password />
		<cfset variables.debug = arguments.debug />
		<cfset variables.timeout = arguments.timeout />
		<cfset variables.tempDir = GetTempDirectory() />
		<cfset variables.apiversion = arguments.apiversion />
		
		<cfset variables.curlPath = arguments.curlPath>
		
		<cfset variables.columnlists['backup'] = "CREATED_AT,ID,PROCESSED,PROCESSED_AT,PROJECT_ID,REQUESTER_ID" />
		
		<cfreturn this />
	</cffunction>
	
	<cffunction name="authenticate" output="false" access="public"  returntype="struct" hint="Tests authentication for unfuddle api. " >
	
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/account"  />
		<cfset var myresult = structNew() />
		<cfset var results = structNew() />
		<cfset results.success = false />
		<cfset results.message = "Not Attempted"/>
		<cfset results.httpcode =  0 />
	
		<cfhttp url="#urlToRequest#" timeout="#variables.timeout#"
			method="get" result="myresult"
			username="#username#" password="#password#">
			<cfhttpparam type="Header" name="Accept-Encoding" value="deflate;q=0">
			<cfhttpparam type="Header" name="TE" value="deflate;q=0">
			<cfhttpparam type="header" name="Accept" value="application/xml" />
			<cfhttpparam type="header" name="Content-Type" value="application/xml" />
		</cfhttp>
		<cfif debug>
			<cffile action="write" file="authenticate.#dateformat(now(),'yyyymmdd')#_#timeformat(now(),'hhmmss')#.xml" output="<!-- #urlToRequest# --> #myresult.fileContent#" />
		</cfif>
		

		<!--- Added to ensure that bad urls are handled correctly. --->
		<cfif not structKeyExists(myresult, "responseHeader") or not structKeyExists(myresult.responseHeader, "status_code")>
			<cfset results.httpcode = "404" />
		<cfelse>
			<cfset results.httpcode = myresult.responseHeader.status_code />
		</cfif>
		
		<cfswitch expression="#results.httpcode#">
			<cfcase value="200">
				<cfset results.message = "Successfully authenticated." />
				<cfset results.success = TRUE />
			</cfcase>
			<cfcase value="401">
				<cfset results.message = "Authentication Failure."/>
			</cfcase>
			<cfcase value="404">
				<cfset results.message = "Unfuddle url does not exist."/>
			</cfcase>
			<cfdefaultcase>
				<cfset results.message = "Unexpected Result: #myresult.responseHeader.status#"/>
			</cfdefaultcase>

		</cfswitch>

		<cfreturn results />
	
	</cffunction>




	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Account Functions                                                                                                                                 --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->

	<cffunction name="getAccount" output="false" access="public"  returntype="query" hint="Get information about the unfuddle account, there is one account per subdomain." >
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/account"  />
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "account") />

		<cfreturn result />
	</cffunction>
	
	<cffunction name="listAccountActivity" output="false" access="public"  returntype="query" hint="Get information about activity on the unfuddle account. It is limited by the permission of the requesting account." >
		<cfargument name="start_date" type="date" hint="Specifies the inclusive start date of the query" />
		<cfargument name="end_date" type="date" hint="Specifies the inclusive start date of the query" />
		<cfargument name="limit" type="numeric" default="0" hint="specifies the maximum number of results to return" />
		
		<cfset var params = structNew() />
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/account/activity"  />
		<cfset var XMLResults = "" />
		<cfset var result = "" />
		
		<cfif structKeyExists(arguments, "start_date")>
			<cfset params.start_date = formatQueryDate(arguments.start_date) />
		</cfif>
		
		<cfif structKeyExists(arguments, "end_date")>
			<cfset params.end_date = formatQueryDate(arguments.end_date) />
		</cfif>
		
		<cfif structKeyExists(arguments, "limit") and arguments.limit gt 0>
			<cfset params.limit = arguments.limit />
		</cfif>
		
		
		<cfif StructIsEmpty(params)>
			<cfset XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfelse>
			<cfset XMLResults = makeHTTPGetRequest(UrlToRequest,params) />
		</cfif>
		
		<cfset result = convertUnfuddleXMLToQuery(XMLResults, "event", "events") />

		<cfreturn result />
	</cffunction>
	
	<cffunction name="searchAccount" output="false" access="public"  returntype="any" hint="searches all projects in the account" >
		<cfargument name="query" type="string" required="true" hint="the query string to search for">
		<cfargument name="filter" type="string" required="false" default="changesets,comments,messages,milestones,notebooks,tickets">
		<cfset var local = structNew()>
		<cfset local.postStruct			= structNew()>
		<cfset local.postStruct.query	= arguments.query>
		<cfset local.postStruct.filter	= arguments.filter>
		<cfset local.postStruct.start_index = 0>
		<cfset local.postStruct.end_index = 50>
		<cfset local.UrlToRequest		= variables.unfuddleUrl & "/api/#variables.apiversion#/account/search?query=#arguments.query#&filter=#arguments.filter#"/>
		<cfset local.XMLResults			= makeHTTPGetRequest(local.UrlToRequest) />
		<cfset local.result				= convertUnfuddleXMLToQuery(local.XMLResults, "result","results") />
		<cfreturn local.result />
	</cffunction>

	<cffunction name="listPeople" output="false" access="public"  returntype="any" hint="lists all of the people associated with the account" >
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/people"  />
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "person","people") />
		<cfreturn result />
	</cffunction>
	
	<cffunction name="getPersonBy" output="false" access="public" returntype="query" hint="Gets a person by a custom defined value">
		<cfargument name="column" type="any" required="true" hint="the column in which to search against">
		<cfargument name="value" type="any" required="true" hint="the value that you are looking for">
		<cfset var local = structNew()>
		<cfset local.users = listPeople()>
		<cfquery name="local.user" dbtype="query">
		SELECT *
		FROM [local].users
		WHERE
			#arguments.column# = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.value#">
		</cfquery>
		<cfreturn local.user>
	</cffunction>
	
	<cffunction name="addPerson" output="false" access="public" returntype="query" hint="Adds a new person to the account" >
		<cfargument name="username" type="string" required="true">
		<cfargument name="email" type="string" required="true">
		<cfargument name="firstName" type="string" required="true">
		<cfargument name="lastName" type="string" required="true">
		<cfargument name="isAdministrator" type="boolean" required="false" default="false">
		<cfargument name="notificationFrequency" type="string" required="false" default="immediate" hint="immediate, 30mins, hourly, dailyam, dailypm, never">
		<cfargument name="notificationIgnoreSelf" type="boolean" required="false" default="true" hint="true, false">
		<cfargument name="notificationScopeMessages" type="string" required="false" default="all" hint="all, none">
		<cfargument name="notificationScopeMilestones" type="string" required="false" default="all" hint="all, none">
		<cfargument name="notificationScopeSource" type="string" required="false" default="all" hint="all, none">
		<cfargument name="notificationScopeTickets" type="string" required="false" default="involved" hint="all, involved, none">
		<cfargument name="timeZone" type="string" required="false" hint="Defaults to the account time zone, otherwise just pass in the string of the time zone">
		<cfset var local = structNew()>
		
		<cfif NOT structKeyExists(arguments,"timeZone")>
			<cfset local.account = getAccount()>
			<cfset arguments.timeZone = local.account.default_time_zone>
		</cfif>
		
		<cfset local.postStruct									= structNew()>
		<cfset local.postStruct.username						= arguments.username>
		<cfset local.postStruct.email							= arguments.email>
		<cfset local.postStruct.first_Name						= arguments.firstName>
		<cfset local.postStruct.last_Name						= arguments.lastName>
		<cfset local.postStruct.is_administrator				= arguments.isAdministrator>
		<cfset local.postStruct.notification_frequency			= arguments.notificationFrequency>
		<cfset local.postStruct.notification_ignore_self		= arguments.notificationIgnoreSelf>
		<cfset local.postStruct.notification_scope_messages		= arguments.notificationScopeMessages>
		<cfset local.postStruct.notification_scope_milestones	= arguments.notificationScopeMilestones>
		<cfset local.postStruct.notification_scope_source		= arguments.notificationScopeSource>
		<cfset local.postStruct.notification_scope_tickets		= arguments.notificationScopeTickets>
		<cfset local.postStruct.time_zone						= xmlFormat(arguments.timeZone)>
		<cfset local.postStruct.notification_last_sent			= formatQueryDate(now())>
		<cfset local.UrlToRequest		= variables.unfuddleUrl & "/api/#variables.apiversion#/people"/>
		<cfset local.XMLResults			= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"person") />
		<cfset local.result				= convertUnfuddleXMLToQuery(local.XMLResults, "person") />
		<cfreturn local.result />
	</cffunction>
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Account Functions                                                                                                                                 --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	
	
	
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Backup Functions                                                                                                                                  --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	
	<cffunction name="createBackup" output="false" access="public"  returntype="query" hint="Requests a new backup. " >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve backups." />
	
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/" & arguments.project & "/backups"/>
		<cfset var XMLResults = makeHTTPPostRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "backup") />

		<cfreturn result />
	</cffunction>
	
	<cffunction name="downloadBackup" output="false" access="public"  returntype="string" hint="Gets a particular backup." >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve backups." />
		<cfargument name="backup" type="any" required="TRUE" hint="The backup id to retrieve." />
		<cfargument name="path" type="any" required="TRUE" hint="Where to download the backup file to." />
		<cfargument name="timeout" type="any" default="120" hint="A timeout value for just this operation." />
		
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/" & arguments.project & "/backups/" & arguments.backup & "/download"/>
		<cfset var accountInfo = getAccount() />
		<cfset var projectInfo = getProject(arguments.project) />
		<cfset var backupInfo = getBackup(arguments.project,arguments.backup) />
		<cfset var fileName = "#accountInfo.subdomain#.#projectInfo.short_name#.#DateFormat(backupInfo.created_at,'yyyymmdd')##TimeFormat(backupInfo.created_at,'hhmmss')#.tar.gz" />
		
		<cfhttp url="#UrlToRequest#" getAsBinary="auto"
			method="get"result="myresult" timeout="#arguments.timeout#"
			username="#username#" password="#password#" path="#arguments.path#" file="#fileName#">
		</cfhttp>
	
	</cffunction>
	
	<cffunction name="getBackup" output="false" access="public"  returntype="query" hint="gets the metadata of a backup. " >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve backups." />
		<cfargument name="backup" type="any" required="TRUE" hint="The backup id to retrieve." />
	
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/" & arguments.project & "/backups/" & arguments.backup />
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "backup") />

		<cfreturn result />
	</cffunction>
	
	<cffunction name="listBackups" output="false" access="public"  returntype="any" hint="Lists all of the backups for a project in the unfuddle account." >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve backups." />
		
	
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/" & arguments.project & "/backups"/>
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "backup","backups") />

		<cfreturn result />
	</cffunction>
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Backup Functions                                                                                                                                  --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	
	
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Project Functions                                                                                                                                 --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<cffunction name="getProject" output="false" access="public"  returntype="any" hint="Gets a project from the unfuddle account." >
		<cfargument name="project" type="any" required="TRUE" hint="Either the project id or project shortname to retrieve. " />
		
		<cfset var UrlToRequest ="" />
		<cfset var XMLResults ="" />
		<cfset var result = "" />
	
		<cfif isNumeric(arguments.project)>
			<cfset UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/" & arguments.project  />
		<cfelse>
			<cfset UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/by_short_name/" & arguments.project   />
		</cfif>
	
		
		<cfset XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset result = convertUnfuddleXMLToQuery(XMLResults, "project") />

		<cfreturn result />
	</cffunction>
	
	<cffunction name="listProjects" output="false" access="public"  returntype="any" hint="lists all of the projects in the unfuddle account. " >
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects"  />
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "project","projects") />
		<cfreturn result />
	</cffunction>
	
	<cffunction name="searchProject" output="false" access="public"  returntype="any" hint="lists all of the projects in the unfuddle account. " >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to search against." />
		<cfargument name="query" type="string" required="true" hint="the query string to search for">
		<cfargument name="filter" type="string" required="false" default="changesets,comments,messages,milestones,notebooks,tickets">
		<cfset var local = structNew()>
		<cfset local.postStruct			= structNew()>
		<cfset local.postStruct.query	= arguments.query>
		<cfset local.postStruct.filter	= arguments.filter>
		<cfset local.postStruct.start_index = 0>
		<cfset local.postStruct.end_index = 50>
		<cfset local.UrlToRequest		= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/search?query=#arguments.query#&filter=#arguments.filter#"/>
		<cfset local.XMLResults			= makeHTTPGetRequest(local.UrlToRequest) />
		<cfset local.result				= convertUnfuddleXMLToQuery(local.XMLResults, "result","results") />
		<cfreturn local.result />
	</cffunction>

	<cffunction name="listPeopleInProject" output="false" access="public"  returntype="any" hint="lists all of the people associated with the project" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to search against." />
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/people"  />
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "person","people") />
		<cfreturn result />
	</cffunction>
	
	<cffunction name="getPersonInProjectBy" output="false" access="public" returntype="query" hint="Gets a custom field by it's value">
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfargument name="column" type="any" required="true" hint="the column in which to search against">
		<cfargument name="value" type="any" required="true" hint="the value that you are looking for">
		<cfset var local = structNew()>
		<cfset local.users = listPeopleInProject(arguments.project)>
		<cfquery name="local.user" dbtype="query">
		SELECT *
		FROM [local].users
		WHERE
			#arguments.column# = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.value#">
		</cfquery>
		<!--- <cfif local.user.recordCount IS 0>
			<cfquery name="local.user" dbtype="query">
			SELECT *
			FROM [local].users
			WHERE
				username = <cfqueryparam cfsqltype="cf_sql_varchar" value="jblayter">
			</cfquery>
		</cfif> --->
		<cfreturn local.user>
	</cffunction>

	<cffunction name="addPersonToProject" output="false" access="public" returntype="query" hint="Adds a person to a project" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to add the version to" />
		<cfargument name="personId" type="numeric" required="true" hint="The ID of the person to add to the project">
		<cfargument name="isAdministrator" type="boolean" required="false" default="false">
		<cfargument name="messages" type="string" required="false" default="readcreate" hint="none, read, readcreate, manage">
		<cfargument name="milestones" type="string" required="false" default="read" hint="none, read, manage">
		<cfargument name="notebooks" type="string" required="false" default="manage" hint="none, read, manage">
		<cfargument name="people" type="string" required="false" default="read" hint="none, read, invite, manage">
		<cfargument name="source" type="string" required="false" default="read" hint="none, read, commit">
		<cfargument name="tickets" type="string" required="false" default="readcreate" hint="none, read, create, readcreate, manage">
		<cfset var local = structNew()>
		<cfset local.postStruct						= structNew()>
		<cfset local.postStruct.person_id			= arguments.personId>
		<cfset local.postStruct.is_administrator	= arguments.isAdministrator>
		<cfset local.postStruct.messages			= arguments.messages>
		<cfset local.postStruct.milestones			= arguments.milestones>
		<cfset local.postStruct.notebooks			= arguments.notebooks>
		<cfset local.postStruct.people				= arguments.people>
		<cfset local.postStruct.source				= arguments.source>
		<cfset local.postStruct.tickets				= arguments.tickets>
		<cfset local.UrlToRequest		= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/involvements"/>
		<cfset local.XMLResults			= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"involvement") />
		<cfset local.result				= convertUnfuddleXMLToQuery(local.XMLResults, "involvement") />
		<cfreturn local.result />
	</cffunction>
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Project Functions                                                                                                                                 --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->



	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Versions                                                                                                                                          --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	
	<cffunction name="listVersions" output="false" access="public"  returntype="any" hint="lists all of the projects in the unfuddle account. " >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve versions." />
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/versions"  />
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "version","versions") />
		<cfreturn result />
	</cffunction>
	
	<cffunction name="addVersion" output="false" access="public" returntype="query" hint="Adds a new version" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to add the version to" />
		<cfargument name="name" type="string" required="true" hint="The name of the version to add">
		<cfset var local = structNew()>
		<cfset local.postStruct			= structNew()>
		<cfset local.postStruct.name	= arguments.name>
		<cfset local.UrlToRequest		= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/versions"/>
		<cfset local.XMLResults			= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"version") />
		<cfset local.result				= convertUnfuddleXMLToQuery(local.XMLResults, "version") />
		<cfreturn local.result />
	</cffunction>
		
	<cffunction name="updateVersion" output="false" access="public" returntype="void" hint="Updates an existing version" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to add the version to" />
		<cfargument name="versionId" type="numeric" required="true" hint="The id of the version that is being updates">
		<cfargument name="name" type="string" required="true" hint="The name of the version">
		<cfset var local = structNew()>
		<cfset local.postStruct			= structNew()>
		<cfset local.postStruct.name	= arguments.name>
		<cfset local.UrlToRequest		= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/versions/#arguments.versionId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"version","put") />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
		<cfreturn/>
	</cffunction>
	
	<cffunction name="deleteVersion" output="false" access="public" returntype="void" hint="deletes a version" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the version to" />
		<cfargument name="versionId" type="numeric" required="true" hint="The version id to delete">
		<cfset var local = structNew()>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/versions/#arguments.versionId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPDeleteRequest(local.UrlToRequest) />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Versions                                                                                                                                          --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	



	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Milestones                                                                                                                                        --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
		
	<cffunction name="listMilestones" output="false" access="public" returntype="any" hint="lists all of the milestones" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve versions." />
		<cfargument name="subset" type="string" required="false" default="" hint="The subset upcoming/late/completed/archived">
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/milestones/#arguments.subset#">
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "milestone","milestones") />
		<cfreturn result />
	</cffunction>

	<cffunction name="addMilestone" output="false" access="public" returntype="query" hint="Adds a new milestone" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the milestone to" />
		<cfargument name="title" type="string" required="true" hint="The title of the milestone to add">
		<cfargument name="dueOn" type="date" required="true" hint="The date that the milestone is due on">
		<cfargument name="personResponsibleId" required="false" type="numeric" default="0" hint="The id person that is responsible for the milestone">
		<cfargument name="archived" type="boolean" required="false" default="false" hint="boolean flag if the milestone is archived or not">
		<cfargument name="completed" type="boolean" required="false" default="false" hint="boolean flag if the milestone is completed or not">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.title		= arguments.title>
		<cfset local.postStruct.due_on		= formatQueryDate(arguments.dueOn)>
		<cfset local.postStruct.person_responsible_id = arguments.personResponsibleId>
		<cfset local.postStruct.archived	= arguments.archived>
		<cfset local.postStruct.completed	= arguments.completed>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/milestones"/>
		<cfset local.XMLResults				= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"milestone") />
		<cfset local.result					= convertUnfuddleXMLToQuery(local.XMLResults, "milestone") />
		<cfreturn local.result />
	</cffunction>
	
	<cffunction name="updateMilestone" output="false" access="public" returntype="void" hint="updates a milestone" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the version to" />
		<cfargument name="mileStoneId" type="numeric" required="true" hint="The milestone id to update">
		<cfargument name="title" type="string" required="true" hint="The title of the milestone to add">
		<cfargument name="dueOn" type="date" required="true" hint="The date that the milestone is due on">
		<cfargument name="personResponsibleId" required="false" type="numeric" default="0" hint="The id person that is responsible for the milestone">
		<cfargument name="archived" type="boolean" required="false" default="false" hint="boolean flag if the milestone is archived or not">
		<cfargument name="completed" type="boolean" required="false" default="false" hint="boolean flag if the milestone is completed or not">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.title		= arguments.title>
		<cfset local.postStruct.due_on		= formatQueryDate(arguments.dueOn)>
		<cfset local.postStruct.person_responsible_id = arguments.personResponsibleId>
		<cfset local.postStruct.archived	= arguments.archived>
		<cfset local.postStruct.completed	= arguments.completed>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/milestones/#arguments.mileStoneId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"milestone","put") />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="deleteMilestone" output="false" access="public" returntype="void" hint="deletes a milestone" >
		<cfargument name="project" type="any" required="true" hint="The project id for which the milestone is in" />
		<cfargument name="mileStoneId" type="numeric" required="true" hint="The milestone id to delete">
		<cfset var local = structNew()>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/milestones/#arguments.mileStoneId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPDeleteRequest(local.UrlToRequest) />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="getMilestonesByTitle" output="false" access="public" returntype="query" hint="Gets a custom field by it's value">
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfargument name="title" type="any" required="true" hint="the title of the milestone that you are looking for">
		<cfset var local = structNew()>
		<cfset local.milestones = listMilestones(arguments.project)>
		<cfif local.milestones.recordCount GT 0>
			<cfquery name="local.milestone" dbtype="query">
			SELECT *
			FROM [local].milestones
			WHERE
				[Title] = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.title#">
			</cfquery>
		<cfelse>
			<cfset local.milestone = queryNew("id,title")>
		</cfif>
		<cfreturn local.milestone>
	</cffunction>

	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Milestones                                                                                                                                        --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->




	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Severities                                                                                                                                        --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
		
	<cffunction name="listSeverities" output="false" access="public" returntype="any" hint="lists all of the severities" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/severities">
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "severity","severities") />
		<cfreturn result />
	</cffunction>

	<cffunction name="addSeverity" output="false" access="public" returntype="query" hint="Adds a new severity" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the milestone to" />
		<cfargument name="name" type="string" required="true" hint="The name of the severity to add">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.name		= arguments.name>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/severities"/>
		<cfset local.XMLResults				= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"severity") />
		<cfset local.result					= convertUnfuddleXMLToQuery(local.XMLResults, "severity") />
		<cfreturn local.result />
	</cffunction>
	
	<cffunction name="updateSeverity" output="false" access="public" returntype="void" hint="updates a severity" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the version to" />
		<cfargument name="severityId" type="numeric" required="true" hint="The id of the severity that is being updated">
		<cfargument name="name" type="string" required="true" hint="The name of the severity to be updated">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.name		= arguments.name>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/severities/#arguments.severityId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"severity","put") />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="deleteSeverity" output="false" access="public" returntype="void" hint="deletes a severity" >
		<cfargument name="project" type="any" required="true" hint="The project id for which the milestone is in" />
		<cfargument name="severityId" type="numeric" required="true" hint="The severity id to delete">
		<cfset var local = structNew()>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/severities/#arguments.severityId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPDeleteRequest(local.UrlToRequest) />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="getSeverityByName" output="false" access="public" returntype="query" hint="Gets a custom field by it's value">
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfargument name="name" type="any" required="true" hint="the title of the milestone that you are looking for">
		<cfset var local = structNew()>
		<cfset local.severities = listSeverities(arguments.project)>
		<cfif local.severities.recordCount GT 0>
			<cfquery name="local.severity" dbtype="query">
			SELECT *
			FROM [local].severities
			WHERE
				[name] = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.name#">
			</cfquery>
		<cfelse>
			<cfset local.severity = queryNew("id,name")>
		</cfif>
		<cfreturn local.severity>
	</cffunction>
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Severities                                                                                                                                        --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->




	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Components                                                                                                                                        --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
		
	<cffunction name="listComponents" output="false" access="public" returntype="any" hint="lists all of the components" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/components">
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "component","components") />
		<cfreturn result />
	</cffunction>

	<cffunction name="addComponent" output="false" access="public" returntype="query" hint="Adds a new component" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the component to" />
		<cfargument name="name" type="string" required="true" hint="The name of the component to add">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.name		= arguments.name>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/components"/>
		<cfset local.XMLResults				= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"component") />
		<cfset local.result					= convertUnfuddleXMLToQuery(local.XMLResults, "component") />
		<cfreturn local.result />
	</cffunction>
	
	<cffunction name="updateComponent" output="false" access="public" returntype="void" hint="updates a component" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the version to" />
		<cfargument name="componentId" type="numeric" required="true" hint="The id of the component that is being updated">
		<cfargument name="name" type="string" required="true" hint="The name of the component to be updated">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.name		= arguments.name>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/components/#arguments.componentId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"component","put") />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="deleteComponent" output="false" access="public" returntype="void" hint="deletes a severity" >
		<cfargument name="project" type="any" required="true" hint="The project id for which the milestone is in" />
		<cfargument name="componentId" type="numeric" required="true" hint="The component id to delete">
		<cfset var local = structNew()>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/components/#arguments.componentId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPDeleteRequest(local.UrlToRequest) />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>

	<cffunction name="getComponentByName" output="false" access="public" returntype="query" hint="Gets a custom field by it's value">
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the component to" />
		<cfargument name="name" type="string" required="true" hint="The name of the component to get">
		<cfset var local = structNew()>
		<cfset local.component = listComponents(arguments.project)>
		<cfif local.component.recordCount GT 0>
			<cfquery name="local.component" dbtype="query">
			SELECT *
			FROM [local].component
			WHERE
				[name] = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.name#">
			</cfquery>
		<cfelse>
			<cfset local.component = queryNew("id,name")>
		</cfif>
		
		<cfreturn local.component>
	</cffunction>
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Components                                                                                                                                        --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->



	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Tickets                                                                                                                                           --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->

	<cffunction name="listTickets" output="false" access="public" returntype="any" hint="lists all of the tickets" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve tickets." />
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets">
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "ticket","tickets") />
		<cfreturn result>
	</cffunction>

	<cffunction name="addTicket" output="false" access="public" returntype="query" hint="updates an existing ticket" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the milestone to" />
		<cfargument name="summary" type="string" required="false" default="new" hint="Ticket summary / subject">
		<cfargument name="description" type="string" required="false" default="" hint="The description of the ticket">
		<cfargument name="priority" type="numeric" required="false" default="1" hint="The ID of the priority (1-5) 1 being the lowest">
		<cfargument name="componentId" type="numeric" required="false" default="0" hint="The ID of the component">
		<cfargument name="descriptionFormat" type="string" required="false" default="plain" hint="The format of the description">
		<cfargument name="dueOn" type="date" required="false" hint="The date that the ticket is due on">
		<cfargument name="milestoneId" type="numeric" required="false" default="0" hint="The ID of the milestone associated with the ticket">
		<cfargument name="resolution" type="string" required="false" default="" hint="The resolution (fixed, works_for_me, postponed, duplicate, will_not_fix, invalid)">
		<cfargument name="resolutionDescription" type="string" required="false" default="" hint="The resolution description">
		<cfargument name="resolutionDescriptionFormat" type="string" required="false" default="plain" hint="The resolution description">
		<cfargument name="severityId" type="numeric" required="false" default="0" hint="The ID of the severity associated with the ticket">
		<cfargument name="status" type="string" required="false" default="new" hint="Status (new, unaccepted, reassigned, reopened, accepted, resolved, closed)">
		<cfargument name="versionId" type="numeric" required="false" default="1" hint="version id">		
		<cfargument name="hoursEstimateCurrent" type="numeric" required="false" default="0" hint="current effort estimate in hours">
		<cfargument name="hoursEstimateInitial" type="numeric" required="false" default="0" hint="initial effort estimate in hours">
		<cfargument name="field1ValueId" type="numeric" required="false" default="0" hint="custom field id">
		<cfargument name="field2ValueId" type="numeric" required="false" default="0" hint="custom field id">
		<cfargument name="field3ValueId" type="numeric" required="false" default="0" hint="custom field id">
		<cfargument name="assigneeId" type="numeric" required="false" default="0" hint="id of the user that it is assigned to">
		
		<cfset var local = structNew()>
		
		<cfset local.postStruct									= structNew()>
		<cfset local.postStruct.summary							= arguments.summary>
		<cfset local.postStruct.description						= arguments.description>
		<cfset local.postStruct.description_format				= arguments.descriptionFormat>
		<cfset local.postStruct.priority						= arguments.priority>
		<cfset local.postStruct.component_id					= arguments.componentId>
		<cfset local.postSturct.description_format				= arguments.descriptionFormat>
		<cfif structKeyExists(arguments,"dueOn")>
			<cfset local.postStruct.due_on 						= formatQueryDate(arguments.dueOn)>
		</cfif>
		<cfset local.postStruct.milestone_id 					= arguments.milestoneId>
		<cfset local.postStruct.resolution 						= arguments.resolution>
		<cfset local.postStruct.resolution_description			= arguments.resolutionDescription>
		<cfset local.postStruct.resolution_description_format	= arguments.resolutionDescriptionFormat>
		<cfset local.postStruct.severity_id						= arguments.severityId>
		<cfset local.postStruct.status							= arguments.status>
		<cfset local.postStruct.version_id						= arguments.versionId>
		<cfset local.postStruct.hours_estimate_current			= arguments.hoursEstimateCurrent>
		<cfset local.postStruct.hours_estimate_initial			= arguments.hoursEstimateInitial>
		<cfif arguments.field1ValueId GT 0>
			<cfset local.postStruct.field1_value_id				= arguments.field1ValueId>
		</cfif>
		<cfif arguments.field2ValueId GT 0>
			<cfset local.postStruct.field2_value_id				= arguments.field2ValueId>
		</cfif>
		<cfif arguments.field3ValueId GT 0>
			<cfset local.postStruct.field3_value_id				= arguments.field3ValueId>
		</cfif>		
		<cfif arguments.assigneeId GT 0>
			<cfset local.postStruct.assignee_id					= arguments.assigneeId>
		</cfif>			
		<cfset local.UrlToRequest	= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets"/>
		<cfset local.XMLResults		= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"ticket") />
		<cfset local.result			= convertUnfuddleXMLToQuery(local.XMLResults, "ticket") />
		
		<cfreturn local.result />
	</cffunction>

	<cffunction name="updateTicket" output="false" access="public" returntype="query" hint="Adds a new ticket" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the milestone to" />
		<cfargument name="ticketId" type="numeric" required="true" hint="The id of the ticket that is being updated">
		<cfargument name="summary" type="string" required="false" default="new" hint="Ticket summary / subject">
		<cfargument name="description" type="string" required="false" default="" hint="The description of the ticket">
		<cfargument name="priority" type="numeric" required="false" default="1" hint="The ID of the priority (1-5) 1 being the lowest">
		<cfargument name="componentId" type="numeric" required="false" default="0" hint="The ID of the component">
		<cfargument name="descriptionFormat" type="string" required="false" default="plain" hint="The format of the description">
		<cfargument name="dueOn" type="date" required="false" hint="The date that the ticket is due on">
		<cfargument name="milestoneId" type="numeric" required="false" default="0" hint="The ID of the milestone associated with the ticket">
		<cfargument name="resolution" type="string" required="false" default="" hint="The resolution (fixed, works_for_me, postponed, duplicate, will_not_fix, invalid)">
		<cfargument name="resolutionDescription" type="string" required="false" default="" hint="The resolution description">
		<cfargument name="resolutionDescriptionFormat" type="string" required="false" default="plain" hint="The resolution description">
		<cfargument name="severityId" type="numeric" required="false" default="0" hint="The ID of the severity associated with the ticket">
		<cfargument name="status" type="string" required="false" default="new" hint="Status (new, unaccepted, reassigned, reopened, accepted, resolved, closed)">
		<cfargument name="versionId" type="numeric" required="false" default="1" hint="version id">		
		<cfargument name="hoursEstimateCurrent" type="numeric" required="false" default="0" hint="current effort estimate in hours">
		<cfargument name="hoursEstimateInitial" type="numeric" required="false" default="0" hint="initial effort estimate in hours">
		
		<cfset var local = structNew()>
		
		<cfset local.postStruct									= structNew()>
		<cfset local.postStruct.summary							= arguments.summary>
		<cfset local.postStruct.description						= arguments.description>
		<cfset local.postStruct.description_format				= arguments.descriptionFormat>
		<cfset local.postStruct.priority						= arguments.priority>
		<cfset local.postStruct.component_id					= arguments.componentId>
		<cfset local.postSturct.description_format				= arguments.descriptionFormat>
		<cfif structKeyExists(arguments,"dueOn")>
			<cfset local.postStruct.due_on 						= formatQueryDate(arguments.dueOn)>
		</cfif>
		<cfset local.postStruct.milestone_id 					= arguments.milestoneId>
		<cfset local.postStruct.resolution 						= arguments.resolution>
		<cfset local.postStruct.resolution_description			= arguments.resolutionDescription>
		<cfset local.postStruct.resolution_description_format	= arguments.resolutionDescriptionFormat>
		<cfset local.postStruct.severity_id						= arguments.severityId>
		<cfset local.postStruct.status							= arguments.status>
		<cfset local.postStruct.version_id						= arguments.versionId>
		<cfset local.postStruct.hours_estimate_current			= arguments.hoursEstimateCurrent>
		<cfset local.postStruct.hours_estimate_initial			= arguments.hoursEstimateInitial>
		
		<cfset local.UrlToRequest	= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#"/>
		<cfset local.XMLResults		= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"ticket") />
		<cfset local.result			= convertUnfuddleXMLToQuery(local.XMLResults, "ticket") />
		
		<cfreturn local.result />
	</cffunction>
	
	<cffunction name="deleteTicket" output="false" access="public" returntype="void" hint="deletes a ticket" >
		<cfargument name="project" type="any" required="true" hint="The project id for which the milestone is in" />
		<cfargument name="ticketId" type="numeric" required="true" hint="The ticket id to delete">
		<cfset var local = structNew()>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#"/>
		<!--- the following throws an XML parsing error but it works so who cares --->
		<cftry>
			<cfset makeHTTPDeleteRequest(local.UrlToRequest) />
			<cfcatch><!--- do nothing ---></cfcatch>
		</cftry>
	</cffunction>
		
	<cffunction name="addFileToTicket" output="true" returntype="void" access="public">
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the milestone to" />
		<cfargument name="ticketId" type="numeric" required="true" hint="The id of the ticket that the file is being uploaded into">
		<cfargument name="filePath" type="string" required="true" hint="full path to the file to be uploaded">
		<cfargument name="contentType" type="string" required="true" hint="MIME File Type">
		<cfset var local = structNew()>
		<cfset local.UrlToRequest			= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#/attachments/upload"/>
		<cfset local.postData				= structNew()>
		<cfset local.postData.urlToRequest	= local.urlToRequest>
		<cfset local.postData.container		= "attachments">
		<cfset local.postData.contentType	= "application/octet-stream">
		<cfset local.postData.file			= arguments.filePath>
		
		<cfset local.result					= curlPost(arguments.project,arguments.ticketId,arguments.filePath)>
		
		<cfset local.postStruct					= structNew()>
		<!--- <cfset local.postStruct.content_type	= arguments.contentType> --->
		<cfset local.postStruct.filename		= getFileFromPath(arguments.filePath)>
		<cfset local.postStruct.parent_type		= "ticket">
		<cfset local.postStruct.upload			= "<key>#local.result.key#</key>">
		<cfset local.UrlToRequest				= variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#/attachments"/>
		<cfset local.XMLResults					= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"attachment") />
	</cffunction>
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Tickets                                                                                                                                           --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->




	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Custom Fields                                                                                                                                     --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
		
	<cffunction name="listCustomFields" output="false" access="public" returntype="any" hint="lists all of the severities" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfargument name="fieldNumber" type="any" required="false" default="" hint="(optional) the ID of the custom field">
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/custom_field_values/#arguments.fieldNumber#">
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "custom-field-value","custom-field-values") />
		<cfreturn result />
	</cffunction>

	<cffunction name="addCustomFieldValue" output="false" access="public" returntype="query" hint="Adds a new comment to a ticket" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the component to" />
		<cfargument name="fieldNumber" type="numeric" required="true" hint="The ID of the custom field that you are adding the value into">
		<cfargument name="value" type="string" required="true" hint="The value of the custom field">
		<cfset var local = structNew()>
		<cfset local.postStruct					= structNew()>
		<cfset local.postStruct.field_number	= arguments.fieldNumber>
		<cfset local.postStruct.value			= arguments.value>
		<cfset local.UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/custom_field_values">
		<cfset local.XMLResults				= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"custom-field-value") />
		<cfset local.result					= convertUnfuddleXMLToQuery(local.XMLResults, "custom-field-value") />
		<cfreturn local.result />
	</cffunction>
	
	<cffunction name="getCustomFieldByValue" output="false" access="public" returntype="query" hint="Gets a custom field by it's value">
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfargument name="fieldNumber" type="numeric" required="false" hint="the ID of the custom field">
		<cfargument name="value" type="any" required="true" hint="the value that you are looking for">
		<cfset var local = structNew()>
		<cfset local.customFields = listCustomFields(arguments.project)>
		<cfif local.customFields.recordCount GT 0>
			<cfquery name="local.field" dbtype="query">
			SELECT *
			FROM [local].customFields
			WHERE
				[value] = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.value#">
				<cfif structKeyExists(arguments,"fieldNumber")>
						AND
					field_number = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.fieldNumber#">
				</cfif>
			</cfquery>
		<cfelse>
			<cfset local.field = queryNew("id,value")>
		</cfif>
		<cfreturn local.field>
	</cffunction>
	
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Custom Fields                                                                                                                                     --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->




	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Comments                                                                                                                                          --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
		
	<cffunction name="listCommentsFromTickets" output="false" access="public" returntype="any" hint="lists all of the severities" >
		<cfargument name="project" type="any" required="TRUE" hint="The project id for which to retrieve severities." />
		<cfargument name="ticketId" type="numeric" required="true" hint="the ticket id">
		<cfset var UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#/comments">
		<cfset var XMLResults = makeHTTPGetRequest(UrlToRequest) />
		<cfset var result = convertUnfuddleXMLToQuery(XMLResults, "comment","comments") />
		<cfreturn result />
	</cffunction>

	<cffunction name="addCommentToTicket" output="false" access="public" returntype="query" hint="Adds a new comment to a ticket" >
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the component to" />
		<cfargument name="ticketId" type="numeric" required="true" hint="the ticket id">
		<cfargument name="body" type="string" required="true" hint="The body of the comment">
		<cfset var local = structNew()>
		<cfset local.postStruct				= structNew()>
		<cfset local.postStruct.body		= arguments.body>
		<cfset local.UrlToRequest = variables.unfuddleUrl & "/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#/comments">
		<cfset local.XMLResults				= makeHTTPPostRequest(local.UrlToRequest,local.postStruct,"comment") />
		<cfset local.result					= convertUnfuddleXMLToQuery(local.XMLResults, "comment") />
		<cfreturn local.result />
	</cffunction>
		
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Comments                                                                                                                                          --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->




	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Private Functions                                                                                                                                 --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<cffunction access="public" name="curlPost" output="true" returntype="any" hint="uploads a file using CURL">
		<cfargument name="project" type="any" required="true" hint="The project id for which to add the milestone to" />
		<cfargument name="ticketId" type="numeric" required="true" hint="The id of the ticket that the file is being uploaded into">
		<cfargument name="filePath" type="string" required="true" hint="full path to the file to be uploaded">
		
		<cfset var local = structNew()>
		<cfset local.fileName = "#arguments.project#_#arguments.ticketId#_#spanExcluding(getFileFromPath(arguments.filePath),".")#.txt">
		<cfexecute timeout="60" outputfile="#variables.tempDir##local.fileName#" name="#variables.curlPath#" arguments="-i -u #username#:#password# -X POST -H 'Accept: application/xml' -H 'Content-Type: application/octet-stream' -T #arguments.filePath# #variables.unfuddleUrl#/api/#variables.apiversion#/projects/#arguments.project#/tickets/#arguments.ticketId#/attachments/upload"></cfexecute>
		
		<cffile action="read" file="#variables.tempDir##local.fileName#" variable="local.fileContent">
		<cfset local.xmlString = listLast(local.fileContent,"#chr(13)##chr(13)#")>
		<cfset local.xmlString = replaceNoCase(local.xmlString,'<?xml version="1.0" encoding="UTF-8"?>',"")>
		<cfset local.xmlResults = xmlParse(local.xmlString)>
		<cfset local.result = convertUnfuddleXMLToQuery(local.XMLResults, "upload")>
		<cfreturn local.result>
	</cffunction>
	
	<cffunction access="private" name="makeHTTPDeleteRequest" output="false" returntype="any" hint="Encapsulates a HTTP delete" >
		<cfargument name="urlToRequest" type="string" required="yes" hint="The url to request the data from. " />
		<cfset var myresult = structNew() />
		<cfset var XMLResults = "" />
		<cfhttp url="#arguments.urlToRequest#" getAsBinary="never"
			method="delete" result="myresult" timeout="#variables.timeout#"
			username="#username#" password="#password#">
			<cfhttpparam type="Header" name="Accept-Encoding" value="deflate;q=0">
			<cfhttpparam type="Header" name="TE" value="deflate;q=0">
			<cfhttpparam type="header" name="Accept" value="application/xml" />
			<cfhttpparam type="header" name="Content-Type" value="application/xml" />
		</cfhttp>
	
		<cfif not FindNoCase("200", myresult.statusCode)>
			<cfif FindNoCase("404", myresult.statusCode)>
				<cfset XMLResults = XMLNew() />
			<cfelse>
				<cfthrow type="UnfuddleCFC" message="Error in Underlying Web Call" detail="#myresult.statuscode# #arguments.urlToRequest#" />
			</cfif>
		<cfelse>
			<cfset XMLResults = XMLParse(myresult.fileContent) />
			<cfif debug>
				<cffile action="write" file="#variables.tempDir##ReplaceList(arguments.urlToRequest, ':,/', '_,+')#.#dateformat(now(),'yyyymmdd')#_#timeformat(now(),'hhmmss')#.xml" output="#XMLResults#" />
			</cfif>
		</cfif>
	
		<cfreturn XMLResults />
	</cffunction>
	
	<cffunction access="private" name="makeHTTPGetRequest" output="false" returntype="XML" hint="Encapsulates getting the requesting and parsing the Unfuddle results into an XML variable." >
		<cfargument name="urlToRequest" type="string" required="yes" hint="The url to request the data from. " />
		<cfargument name="request" type="struct" required="no" hint="A structured post to send to Unfuddle API.  Usually for creating items." />
	
		<cfset var postVar = "" />
		<cfset var XMLResults = "" />
		<cfset var myresult = structNew() />
		
				
		<cfhttp url="#arguments.urlToRequest#" getAsBinary="never"
			method="get" result="myresult" timeout="#variables.timeout#"
			username="#variables.username#" password="#variables.password#">
			<cfhttpparam type="Header" name="Accept-Encoding" value="deflate;q=0">
			<cfhttpparam type="Header" name="TE" value="deflate;q=0">
			<cfhttpparam type="header" name="Accept" value="application/xml" />
			<cfhttpparam type="header" name="Content-Type" value="application/xml" />
			<cfif structKeyExists(arguments, "request")>
				<cfloop collection="#arguments.request#" item ="key" >
					<cfhttpparam type="url" name="#Lcase(key)#" value="#request[key]#" />
				</cfloop>
			</cfif>
		</cfhttp>
	
		<cfif not FindNoCase("200", myresult.statusCode)>
			<cfif FindNoCase("404", myresult.statusCode)>
				<cfset XMLResults = XMLNew() />
			<cfelse>
				<cfthrow type="UnfuddleCFC" message="Error in Underlying Web Call" detail="#myresult.statuscode# #arguments.urlToRequest#" />
			</cfif>
		<cfelseif len(myresult.fileContent)>
			<cfif debug>
				<cffile action="write" file="#variables.tempDir##ReplaceList(spanExcluding(arguments.urlToRequest,'?'), ':,/', '_,+')#.#dateformat(now(),'yyyymmdd')#_#timeformat(now(),'hhmmss')#.xml" output="<!-- #arguments.urlToRequest# --> #myresult.fileContent#" />
			</cfif>
			<cfset XMLResults = XMLParse(myresult.fileContent) />
		</cfif>
	
		<cfreturn XMLResults />
	</cffunction>
	
	<cffunction access="private" name="makeHTTPPostRequest" output="false" returntype="XML" hint="Encapsulates getting the requesting and parsing the Basecamp results into an XML variable." >
		<cfargument name="urlToRequest" type="string" required="yes" hint="The url to request the data from. " />
		<cfargument name="request" type="struct" required="no" hint="A structured post to send to Unfuddle API.  Usually for creating items." />
		<cfargument name="container" type="string" required="yes" hint="The outside container XML">
		<cfargument name="httpMethod" type="string" required="false" default="post" hint="The HTTP method (post or put)">
		<cfargument name="contentType" type="string" required="false" default="application/xml" hint="This should be application/xml for regular posts OR application/octet-stream for file uploads">
		<cfargument name="file" type="string" required="false" hint="">
		<cfset var XMLResults = "" />
		<cfset var myresult = structNew() />
		<cfset var postvar = "" />
		<cfset var localurlToRequest = arguments.urlToRequest />
		
		<cfif structKeyExists(arguments, "request")>
			<cfset postVar = convertPostRequestToXML(arguments.request,arguments.container) />
		</cfif>
		
		<cfif structKeyExists(arguments, "file") AND arguments.contentType NEQ "application/octet-stream">
			<cfset arguments.contentType = "application/octet-stream">
		</cfif>
		
		<cfif debug>
			<cffile action="write" file="#variables.tempDir##ReplaceList(arguments.urlToRequest, ':,/', '_,+')#.#dateformat(now(),'yyyymmdd')#_#timeformat(now(),'hhmmss')#_postdata.xml" output="#postVar#" />
		</cfif>
		
		<cfhttp username="#variables.username#" timeout="#variables.timeout#" password="#variables.password#" result="myresult" method="#arguments.httpMethod#" url="#localurlToRequest#">
	    	<cfhttpparam type="header" name="Accept" value="application/xml" />
			<cfhttpparam type="header" name="Content-Type" value="application/xml" />
		    <cfhttpparam type="header" name="Accept" value="application/xml" />
		    <cfhttpparam type="header" name="Content-Type" value="#arguments.contentType#" />
		    <cfif structKeyExists(arguments, "request")>
			    <cfhttpparam type="body" name="post" encoded="no" value="#PostVar#" />
			</cfif>
			<cfif structKeyExists(arguments,"file")>
				<cfhttpparam type="file" name="post" encoded="true" file="#arguments.file#">
			</cfif>
		</cfhttp>
	
		<cfif not FindNoCase("200", myresult.statusCode) and not FindNoCase("201", myresult.statusCode)>
			<cfif debug>
				<cffile action="write" file="#variables.tempDir##ReplaceList(arguments.urlToRequest, ':,/', '_,+')#.#dateformat(now(),'yyyymmdd')#_#timeformat(now(),'hhmmss')#.xml" output="#myresult.fileContent#" />
			</cfif>
			<cfthrow type="UnfuddleCFC" message="Error in Underlying Web Call" detail="#myresult.statuscode# url:#localurlToRequest#" />
		</cfif>
		
		<cfif Find("201", myresult.statusCode) AND StructKeyExists(myresult.Responseheader, "Location")>
			<cfif arguments.httpMethod IS "post">
				<cfset XMLResults = makeHTTPGetRequest(myresult.Responseheader.location) />
			</cfif>
		</cfif>
		
		<cfreturn XMLResults />
	</cffunction>
	
	<cffunction access="private" name="convertPostRequestToXML" output="false" returntype="string" hint="Takes a post request structure and converts it to the XML form that Basecamp needs." >
		<cfargument name="request" type="struct" required="yes" default="" hint="The request structure to transform. " />
		<cfargument name="container" type="string" required="yes" hint="The outside container XML">
		<cfset var i = 0 />
		<cfset var attribute = "" />
		<cfset var postVar = "" />
		<cfset var XMLNode = "" />
	
		<cfset postVar = postVar.concat("<#arguments.container#>") & chr(10) />

		<cfloop collection="#arguments.request#" item="attribute">
			<cfif CompareNoCase("item", attribute) neq 0 and CompareNoCase("type", attribute) neq 0>
				<cfset XMLNode = Lcase(Replace(attribute, "_", "-", "ALL")) />
				<cfif isSimpleValue(arguments.request[attribute])>
					<cfset postVar = postVar.concat("		<#XMLNode#>#arguments.request[attribute]#</#XMLNode#>") & chr(10) />
				<cfelseif isArray(arguments.request[attribute])>
					<cfloop index="i" from="1" to="#ArrayLen(arguments.request[attribute])#">
						<cfset postVar = postVar.concat("	<#XMLNode#>#arguments.request[attribute][i]#</#XMLNode#>") & chr(10) />
					</cfloop>
				</cfif>
			</cfif>
	
		</cfloop>
		<cfset postVar = postVar.concat("</#arguments.container#>") & chr(10) />
		
		<cfreturn postVar />
	</cffunction>
	
	<cffunction access="private" name="convertUnfuddleXMLToQuery" output="true" returntype="query" hint="Converts the results from unfuddle into an ColdFusion query variable." >
		<cfargument name="unfuddleXML" type="XML" required="yes" hint="The unfuddle XML content." />
		<cfargument name="collection" type="string" required="yes" hint="The name of the collection to loop over. If the xml structure is 'unfuddlexml.comments.comment',we are looking for 'comment'." />
		<cfargument name="root" type="string" default ="" hint="The root of the XML file, needed if collection is not the root." />
	
		<cfset var keyArray= arrayNew(1) />
		<cfset var QueryResults = QueryNew('') />
		<cfset var i= 0 />
		<cfset var j= 0 />
		<cfset var k= 0 />
		<cfset var r= arguments.root />
		<cfset var c= arguments.collection>
		<cfset var xml = arguments.unfuddleXML />
		<cfset var queryTypes = "" />
		
	
		<cfif len(r) gt 0>
			<cfif StructKeyExists(XML, r) and StructKeyExists(XML[r], c)>
				<cfset keyArray= returnAllSubKeys(XML[r][c], c) />
				
				<cfloop index="k" from="1" to="#ArrayLen(keyArray)#">
					<cfset queryTypes = listAppend(queryTypes, "VarChar")>
				</cfloop>
	
				<cfset QueryResults = QueryNew(Replace(ArrayToList(keyArray), "-", "_", "ALL"), queryTypes) />
			
				<cfloop index="j" from="1" to="#ArrayLen(XML[r][c])#">
					<cfset QueryAddRow(QueryResults) />
					<cfloop index="i" from="1" to="#ArrayLen(keyArray)#">
						<!--- Make sure the item exists. --->
						<cfif structKeyExists(XML[r][c][j], keyArray[i])>
							<!--- If it is marked as a datatime, convert it.  --->
							<cfif IsDateField(keyArray[i]) and structKeyExists(XML[r][c][j][keyArray[i]], "XMLText") and Len(XML[r][c][j][keyArray[i]]['XMLText']) gt 0>
								<cfset QuerySetCell(QueryResults, Replace(keyArray[i], "-", "_", "ALL"), convertunfuddleDateTime(XML[r][c][j][keyArray[i]].XMlText)) />
							<cfelse>
								<cfset QuerySetCell(QueryResults, Replace(keyArray[i], "-", "_", "ALL"), XML[r][c][j][keyArray[i]].XMlText) />
							</cfif>
	
						</cfif>
					</cfloop>
				</cfloop>
			</cfif>
		<cfelse>
			<cfif StructKeyExists(XML, c)>
	
				<cfset keyArray= returnAllSubKeys(XML[c], c) />
				
				<cfloop index="k" from="1" to="#ArrayLen(keyArray)#">
					<cfset queryTypes = listAppend(queryTypes, "VarChar")>
				</cfloop>
				
				<cfset QueryResults = QueryNew(Replace(ArrayToList(keyArray), "-", "_", "ALL"), queryTypes) />
				<cfset QueryAddRow(QueryResults) />
			
				<cfloop index="i" from="1" to="#ArrayLen(keyArray)#">
					<!--- Make sure the item exists. --->
					<cfif structKeyExists(XML[c], keyArray[i])>
						<!--- If it is marked as a datatime, convert it.  --->
						<cfif IsDateField(keyArray[i])  and structKeyExists(XML[c][keyArray[i]], "XMLText") and Len(XML[c][keyArray[i]]['XMLText']) gt 0>
							<cfset QuerySetCell(QueryResults, Replace(keyArray[i], "-", "_", "ALL"), convertunfuddleDateTime(XML[c][keyArray[i]].XMlText)) />
						<cfelse>
												
							<cfset QuerySetCell(QueryResults, Replace(keyArray[i], "-", "_", "ALL"), XML[c][keyArray[i]].XMlText) />
						</cfif>
					</cfif>
				</cfloop>
			</cfif>
		</cfif>
		
		<cfif len(queryResults.ColumnList) eq 0 and StructKeyExists(variables.columnlists, c)>
			<cfset QueryResults = QueryNew(variables.columnlists[c]) />
		</cfif>
	
		<cfreturn QueryResults />
	</cffunction>

	<cffunction access="private" name="convertunfuddleDateTime" output="false" returntype="date" hint="Converts unfuddle time to a ColdFusion date time variable. " >
		<cfargument name="unfuddleTime" type="string" required="yes" hint="The unfuddle formatted date time." />
	
		<cfset var date = "" />
		<cfset var time = ""/>
		<cfset var outputDateTime = "">
		<cfset var localuftime = ReplaceNoCase(arguments.unfuddleTime, "Z", "", "ALL") />
	
		<cfset date = GetToken(localuftime,1,"T") />
		<cfset time = GetToken(GetToken(localuftime,2,"T"), 1,"-") />
		
		<cfset outputDateTime = ParseDateTime(date & " " & time) />
		
		<cfif FindNoCase("Z", arguments.unfuddleTime)>
			<cfset outputDateTime=DateConvert("utc2Local",outputDateTime) />
		</cfif>
	
		<cfreturn outputDateTime />
	</cffunction>
	
	<cffunction access="private" name="returnAllSubKeys" output="false" returntype="array" hint="Takes an Array of structures, and returns a list of all keys. " >
		<cfargument name="array" type="any" required="yes" hint="The array of structures to parse." />
		<cfargument name="collection" type="string" default="" hint="The collection type to parse." />
	
		<cfset var i=0 />
		<cfset var j=0 />
		<cfset var keyHolder = structNew() />
		<cfset var keyArray = ArrayNEw(1) />
		<cfset var returnArray  =ArrayNew(1) />
	
		<cfloop index="i" from="1" to="#ArrayLen(arguments.array)#">
			<cfset keyArray = StructKeyArray(arguments.array[i]) />
	
			<cfloop index="j" from="1" to="#ArrayLen(keyArray)#">
				<cfset keyHolder[keyArray[j]]="" />
			</cfloop>
	
		</cfloop>
		
		<cfif len(arguments.collection) gt 0 AND structKeyExists(ColumnLists, arguments.collection) and
			ListLen(ColumnLists[arguments.collection] gt ArrayLen(returnArray))>
			<cfset returnArray = ListToArray(ColumnLists[arguments.collection] )>
		</cfif>
		
	
		<cfset returnArray  = StructKeyArray(keyholder) />
	
	
	
		<cfreturn returnArray />
	</cffunction>
	
	<cffunction name="isDateField" output="false" access="private"  returntype="boolean" hint="Determines if a field from the XML is a date field." >
		<cfargument name="fieldName" type="string" required="TRUE" hint="The fieldname to check." />
	
		<cfif FindNoCase("created-at", fieldName) OR 
				FindNoCase("updated-at", fieldName) OR
					FindNoCase("processed-at", fieldName)>
			<cfreturn TRUE />
		<cfelse>
			<cfreturn false />
		</cfif>
	</cffunction>

	<cffunction name="formatQueryDate" output="false" access="private"  returntype="string" hint="formats the date used in queries against the api. " >
		<cfargument name="dateToFormat" type="date" required="TRUE" hint="The date to format." />
		<cfreturn DateFormat(arguments.dateToFormat,"yyyy/m/d") />
	</cffunction>

	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->
	<!--- Private Functions                                                                                                                                 --->
	<!--------------------------------------------------------------------------------------------------------------------------------------------------------->




</cfcomponent>