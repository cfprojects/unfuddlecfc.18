<cfcomponent extends="mxunit.framework.TestCase">

	<cffunction name="setUp" returntype="void" access="public" hint="initial startup of the framework">
		<!--- Used in the setup of the test --->
		<cfset var local = structNew()>
		<cfinclude template="testSettings.cfm">
		<cfset variables.unfuddle = createObject("component","unfuddlecfc.cfc.unfuddle").init(argumentCollection=local.settings)>
		<cfset variables.unfuddle.authenticate()>
	</cffunction>

	<cffunction name="testProjectList" returntype="void" access="public">
		<cfset var local = structNew()>
		<cfset local.projects = variables.unfuddle.listProjects()>
		<cfset debug(local.projects)>
		<cfset assertIsQuery(local.projects)>
	</cffunction>

	<cffunction name="testProjectGet" returntype="void" access="public">
		<cfset var local = structNew()>
		<cfset local.projects = variables.unfuddle.listProjects()>
		<cfset local.project = variables.unfuddle.getProject(local.projects.id)>
		<cfset assertEquals(local.projects.title,local.project.title)>
	</cffunction>


</cfcomponent>