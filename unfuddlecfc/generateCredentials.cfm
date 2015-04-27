<cfset AESSecret = "ZvwotygaXFcSil4pGpH0Hg==" />

<cfparam name="form.username" type="string" default="" />
<cfparam name="form.unfuddleurl" type="string" default="" />
<cfparam name="form.project" type="any" default="" />
<cfparam name="form.email" type="any" default="" />
<cfparam name="url.message" type="any" default="" />
<cfparam name="message" type="any" default="#url.message#" />

<cfif structKeyExists(form, "submit")>

	<cfset unfuddle =  CreateObject("component", "unfuddle.cfc.unfuddle").init(username=form.username, password=form.password, unfuddleurl=form.unfuddleurl, debug=false) />
	<cfset auth = unfuddle.authenticate() />
	
	<cfif not auth.success>
		<cfset message = "authfailed" />
	</cfif>

	<cfif auth.success>
		<cfset project = unfuddle.getProject(form.project) />
	
		<cfif project.recordCount lt 1>
			<cfset message = "projectnotexist" />
		</cfif>
		
		<cfif project.recordCount gt 0>
			<cfset projectDirectory = ExpandPath('./projects/#project.id#') />
			<cfset serialForm = duplicate(form) />
			<cfset serialForm['project'] = project.id />
			<cfset structDelete(serialForm, "submit") />
			<cfset structDelete(serialForm, "fieldnames") />
			<cfloop collection="#serialform#" item="field">
				<cfset serialForm[field] = Encrypt(serialForm[field],AESSecret, "AES", "HEX")>
			</cfloop>
		
			<cfwddx action="cfml2wddx" input="#serialForm#" output="wddxForm" />
			<cfif not directoryExists(projectDirectory)>
				<cfdirectory action="create" directory="#projectDirectory#" />
			</cfif>
			<cfset FileWrite(projectDirectory & "/credentials.cfm", "<cfabort>#wddxForm#") />
			<cflocation url="processBackups.cfm?project_id=#project.id#" addtoken="no" />
		
		</cfif>
	</cfif>	





</cfif>

<cfif FindNoCase("authfailed", message)>
	<p class="alert">Authentication Failed.</p>
<cfelseif FindNoCase("projectnotexist", message)>
	<p class="alert">The project you selected does not exist.</p>
<cfelseif FindNoCase("credsmissing", message)>
	<p class="alert">Credentials do not exist for the project you wish to backup, enter them below.</p>			
<cfelse>
	<p>Please pass the credentials of the Unfuddle project that you want to backup. </p>
</cfif>

<cfform action="#cgi.script_name#" method="post">
	<label for="username">Username: </label>
	<cfinput name="username" type="text" class="text" id="username" required="true" value="#form.username#" message="You must enter an username" /><br />

	<label for="password">Password: </label>
	<cfinput name="password" type="password" class="password"  id="password" required="true" value="" message="You give enter a password" /><br />

	<label for="unfuddleurl">Unfuddle URL: </label>
	<cfinput name="unfuddleurl" type="text" class="text"  id="unfuddleurl" required="true" value="#form.unfuddleurl#" message="You must enter an Unfuddle URL" /><br />

	<label for="project">Project: </label>
	<cfinput name="project" type="text" class="text"  id="project" required="true" value="#form.project#" message="You must enter an Unfuddle project" /><br />
	
	<label for="email">Notify Email: </label>
	<cfinput name="email" type="text" class="text"  id="email" required="true" value="#form.email#" message="You must enter an Unfuddle project" /><br />

	<cfinput name="submit" value="Submit" type="submit" class="submit" />
	
	<p>
		<a href="documentation/index.html">UnfuddleCFC Documentation</a>
	</p>
	
</cfform>