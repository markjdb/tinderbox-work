<?php
$topmenu = array(
	"Current and latest builds in this build" 	=> "index.php?action=latest_buildports&amp;build=$build_name",
	"Failed builds in this build"				=> "index.php?action=failed_buildports&amp;build=$build_name"
);
$header_title = $build_name;
include 'header.inc.tpl';
?>
<!-- $Paefchen: FreeBSD/tinderbox/webui/templates/paefchen/list_buildports.tpl,v 1.2 2008/01/07 03:53:59 as Exp $ //-->
<h1><?php echo $build_name?> � <?php echo $build_description?></h1>
<div class="description">
	<table>
		<tr>
			<th></th>
			<th>Name</th>
			<th>Updated</th>
		</tr>
		<tr>
			<th>System</th>
			<td>FreeBSD <?php echo $jail_name?> (<?php echo $jail_tag?>)</td>
			<td><?php echo $jail_lastbuilt?></td>
		</tr>
 		<tr>
  			<th>Ports Tree</th>
  			<td><?php echo $ports_tree_description?></td>
			<td><?php echo $ports_tree_lastbuilt?></td>
	 	</tr>
	</table>
</div>

<div class="subcontent">
	<form method="get" action="index.php">
	<table>
		<tr>
			<th>Failed builds in this build for the maintainer</th>
		</tr>
		<tr>
			<td>
 				<input type="hidden" name="action" value="failed_buildports" />
				<input type="hidden" name="build" value="<?php echo $build_name?>" />
				<select name="maintainer">
					<option></option>
<?php foreach($maintainers as $maintainer) {?>
					<option><?php echo $maintainer?></option>
<?php }?>
				</select>
				<input type="submit" name="Go" value="Go" />
			</td>
		</tr>
	</table>
	</form>
</div>

<?php if(!$no_list){?>
<table>
	<tr>
		<th>
			<a href="<?php echo  build_query_string($_SERVER['PHP_SELF'], $querystring, "sort", "port_directory") ?>">Port Directory</a>
		</th>
		<th>
			<a href="<?php echo  build_query_string($_SERVER['PHP_SELF'], $querystring, "sort", "port_maintainer") ?>">Maintainer</a>
		</th>
		<th>
			<a href="<?php echo  build_query_string($_SERVER['PHP_SELF'], $querystring, "sort", "last_built_version") ?>">Version</a>
		</th>
		<th style="width: 20px">&nbsp;</th>
		<th>
			<a href="<?php echo  build_query_string($_SERVER['PHP_SELF'], $querystring, "sort", "last_fail_reason") ?>">Reason</a>
		</th>
		<th>&nbsp;</th>
		<th>
			<a href="<?php echo  build_query_string($_SERVER['PHP_SELF'], $querystring, "sort", "last_built") ?>">Last Build Attempt</a>
		</th>
		<th>
			<a href="<?php echo  build_query_string($_SERVER['PHP_SELF'], $querystring, "sort", "last_successful_built") ?>">Last Successful Build</a>
		</th>
	</tr>
	<?php foreach($data as $row) {?>
	<tr>
		<td><a href="index.php?action=describe_port&amp;id=<?php echo $row['port_id']?>"><?php echo $row['port_directory']?></a></td>
		<td><?php echo $row['port_maintainer']?></td>
		<td><?php echo $row['port_last_built_version']?></td>
		<td class="<?php echo $row['status_field_class']?>"><?php echo $row['status_field_letter']?></td>
		<?php $reason=$row['port_last_fail_reason']?>
		<td class="<?php echo "fail_reason_".$port_fail_reasons[$reason]['type']?>">
		<?php $href=($port_fail_reasons[$reason]['link']) ? "index.php?action=display_failure_reasons&amp;failure_reason_tag=$reason#$reason" : "#"?>
		<a href="<?php echo $href?>" class="<?php echo "fail_reason_".$port_fail_reasons[$reason]['type']?>" title="<?php echo $port_fail_reasons[$reason]['descr']?>"><?php echo $reason?></a>
		</td>
		<td>
		<?php if($row['port_link_logfile']){?>
			<a href="<?php echo $row['port_link_logfile']?>">log</a>
		<?php }?>
		<?php if($row['port_link_package']){?>
			<a href="<?php echo $row['port_link_package']?>">package</a>
		<?php }?>
		</td>
		<td><?php echo $row['port_last_built']?></td>
		<td><?php echo $row['port_last_successful_built']?></td>
	</tr>
	<?php }?>
</table>
<p>Total: <?php echo count($data)?></p>
<?php }else{?>
<p>No ports are being built.</p>
<?php }?>

<div class="subcontent">
	<form method="get" action="index.php">
	<table>
		<tr>
			<th>Failed builds in this build for the maintainer</th>
		</tr>
		<tr>
			<td>
 				<input type="hidden" name="action" value="failed_buildports" />
				<input type="hidden" name="build" value="<?php echo $build_name?>" />
				<select name="maintainer">
					<option></option>
<?php foreach($maintainers as $maintainer) {?>
					<option><?php echo $maintainer?></option>
<?php }?>
				</select>
				<input type="submit" name="Go" value="Go" /><br />
			</td>
		</tr>
	</table>
	</form>
</div>
<?php
$footer_legend = array(
	'port_success'	=> 'Success',
	'port_default'	=> 'Default',
	'port_leftovers'=> 'Leftovers', # L
	'port_dud'		=> 'Dud', # D
	'port_depend'	=> 'Depend',
	'port_fail'		=> 'Fail',
);
include 'footer.inc.tpl';
?>
