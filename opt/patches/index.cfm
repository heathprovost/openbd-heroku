<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
	<title><cfoutput>Welcome to OpenBD for Heroku</cfoutput></title>
	<style type="text/css">
		body {font-family: "CorbelRegular", "Helvetica Neue", Helvetica, Arial, Geneva, sans-serif; color: #FFF; background: #1D1D1D; padding:20px;}
		a {color: #29264D;}
		h1 {display: block; margin-top: 0; padding: 15px 20px; font-weight: normal; background-color: #29264D; border-bottom: 3px solid #494573; text-align: center;}
		table {padding: 0; margin: 0px auto; border-collapse: collapse; border: 1px solid #494573;}
		th, td {font-weight: normal; padding: 15px;}
		th {padding: 20px; font-size: 26px; color: #FFF; background-color: #29264D; border-bottom: 5px solid #494573;}
		td {color: #29264D; background: #FFF;}
		td.alt {background: #F5FAFA; color: #797268;}
	</style>
</head>
<body>
<cfoutput>
	<table cellspacing="0">
		<thead>
			<tr>
				<th colspan="2">Welcome to OpenBD for Heroku</th>
			</tr>
		</thead>
		<tbody>
			<tr>
				<td>Application Server</td>
				<td><a href="http://openbd.org/">Open #server.coldfusion.productname# #replace(server.coldfusion.productversion, ",", ".", "all")#</a> (#left(server.bluedragon.builddate, 10)#)</td>
			</tr>
			<tr>
				<td>Servlet Engine</td>
				<td><a href="http://winstone.sourceforge.net/">#server.coldfusion.appserver#</a></td>
			</tr>
			<tr>
				<td>Operating System</td>
				<td>#server.os.name# #server.os.version#</td>
			</tr>
			<tr>
				<td>CPU Architecture</td>
				<td>#server.os.arch#</td>
			</tr>
		<tbody>	
	</table>	
</cfoutput>
</body>
</html>