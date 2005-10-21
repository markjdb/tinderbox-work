<?php
#-
# Copyright (c) 2004-2005 FreeBSD GNOME Team <freebsd-gnome@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $MCom: portstools/tinderbox/webui/core/TinderboxDS.php,v 1.21 2005/10/21 22:40:14 oliver Exp $
#

    require_once 'DB.php';
    require_once 'Build.php';
    require_once 'BuildPortsQueue.php';
    require_once 'Host.php';
    require_once 'Jail.php';
    require_once 'Port.php';
    require_once 'PortsTree.php';
    require_once 'PortFailReason.php';
    require_once 'User.php';
    require_once 'inc_ds.php';
    require_once 'inc_tinderbox.php';

    $objectMap = array(
        "Build" => "builds",
        "BuildPortsQueue" => "build_ports_queue",
        "Host"  => "hosts",
        "Jail"  => "jails",
        "Port"  => "ports",
        "PortsTree" => "ports_trees",
        "PortFailReason" => "port_fail_reasons",
        "User"  => "users",
    );

    class TinderboxDS {
        var $db;
        var $error;
        var $packageSuffixCache; /* in use by getPackageSuffix() */

        function TinderboxDS() {
            global $DB_HOST, $DB_DRIVER, $DB_NAME, $DB_USER, $DB_PASS;

            # XXX: backwards compatibility
            if ($DB_DRIVER == "")
                $DB_DRIVER = "mysql";

            $dsn = "$DB_DRIVER://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME";

            $this->db = DB::connect($dsn);

            if (DB::isError($this->db)) {
                die ("Tinderbox DS: Unable to initialize datastore: " . $this->db->getMessage() . "\n");
            }

            $this->db->setFetchMode(DB_FETCHMODE_ASSOC);
            $this->db->setOption('persistent', true);
        }

        function start_transaction() {
                $this->db->autoCommit( false );
        }

        function commit_transaction() {
                $this->db->commit();
                $this->db->autoCommit( true );
        }

        function rollback_transaction() {
                $this->db->rollback();
                $this->db->autoCommit( true );
        }

        function getAllMaintainers() {
            $query = "SELECT DISTINCT LOWER(port_maintainer) AS port_maintainer FROM ports where port_maintainer IS NOT NULL ORDER BY LOWER(port_maintainer)";
            $rc = $this->_doQueryHashRef($query, $results, array());

            if (!$rc) {
                return array();
            }

            foreach($results as $result)
                $data[]=$result['port_maintainer'];

            return $data;
        }

        function getAllPortsByPortID($portid) {
            $query = "SELECT ports.*,build_ports.build_id,build_ports.last_built,build_ports.last_status,build_ports.last_successful_built,last_built_version FROM ports,build_ports WHERE ports.port_id = build_ports.port_id AND build_ports.port_id=$portid";
            $rc = $this->_doQueryHashRef($query, $results, array());

            if (!$rc) {
                return null;
            }

            $ports = $this->_newFromArray("Port", $results);

            return $ports;
        }


        function addUser($user) {
            $query = "INSERT INTO users
                         (user_name,user_email,user_password,user_www_enabled)
                      VALUES
                         (?,?,?,?)";

            $rc = $this->_doQuery($query, array($user->getName(),$user->getEmail(),$user->getPassword(),$user->getWwwEnabled()),$res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function deleteUser($user) {
            if( !$user->getId() || $this->deleteUserPermissions($user,'') ) {
                    if( $user->getId()) {
                        $this->deleteBuildPortsQueueByUserId($user);
                }
                $query = "DELETE FROM users
                                WHERE user_name=?";

                $rc = $this->_doQuery($query, array($user->getName()),$res);

                if (!$rc) {
                     return false;
                }

                return true;
            }
            return false;
        }

        function updateUser($user) {
            $query = "UPDATE users
                         SET user_name=?,user_email=?,user_password=?,user_www_enabled=?
                       WHERE user_id=?";

            $rc = $this->_doQuery($query, array($user->getName(),$user->getEmail(),$user->getPassword(),$user->getWwwEnabled(),$user->getId()),$res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function getUserByLogin($username,$password) {
            $hashPass = md5($password);
            $query = "SELECT user_id,user_name,user_email,user_password,user_www_enabled FROM users WHERE user_name=? AND user_password=?";
            $rc = $this->_doQueryHashRef($query, $results, array($username,$hashPass));

            if (!$rc) {
                return null;
            }

            $user = $this->_newFromArray("User", $results);

            return $user[0];
        }

        function getUserPermissions($user_id,$host_id,$object_type,$object_id) {

            $query = "
                SELECT
                CASE user_permission
                   WHEN 1 THEN 'IS_WWW_ADMIN'
                   WHEN 2 THEN 'PERM_ADD_QUEUE'
                   WHEN 3 THEN 'PERM_MODIFY_OWN_QUEUE'
                   WHEN 4 THEN 'PERM_DELETE_OWN_QUEUE'
                   WHEN 5 THEN 'PERM_PRIO_LOWER_5'
                   WHEN 6 THEN 'PERM_MODIFY_OTHER_QUEUE'
                   WHEN 7 THEN 'PERM_DELETE_OTHER_QUEUE'
                   ELSE 'PERM_UNKNOWN'
                END
                   AS user_permission
                 FROM user_permissions
                WHERE user_id=?
                  AND host_id=?
                  AND user_permission_object_type=?
                  AND user_permission_object_id=?";

            $rc = $this->_doQueryHashRef($query, $results, array($user_id,$host_id,$object_type,$object_id));

            if (!$rc) {
                return null;
            }

            return $results;
        }

        function deleteUserPermissions($user, $object_type) {

            $query = "
                DELETE FROM user_permissions
                      WHERE user_id=?";

            if( $object_type )
                $query .= " AND user_permission_object_type='$object_type'";

            $rc = $this->_doQuery($query, array($user->getId()), $res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function addUserPermission($user_id,$host_id,$object_type,$object_id,$permission) {

            switch( $permission ) {
//              case 'IS_WWW_ADMIN':             $permission = 1; break;   /* only configureable via shell */
                case 'PERM_ADD_QUEUE':           $permission = 2; break;
                case 'PERM_MODIFY_OWN_QUEUE':    $permission = 3; break;
                case 'PERM_DELETE_OWN_QUEUE':    $permission = 4; break;
                case 'PERM_PRIO_LOWER_5':        $permission = 5; break;
                case 'PERM_MODIFY_OTHER_QUEUE':  $permission = 6; break;
                case 'PERM_DELETE_OTHER_QUEUE':  $permission = 7; break;
                default:                         return false;
            }

            $query = "
                INSERT INTO user_permissions
                    (user_id,host_id,user_permission_object_type,user_permission_object_id,user_permission)
                   VALUES
                    (?,?,?,?,?)";

            $rc = $this->_doQuery($query, array($user_id,$host_id,$object_type,$object_id,$permission), $res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function getBuildPortsQueueEntries($host_id,$build_id) {
            $query = "SELECT build_ports_queue.*, builds.build_name AS build_name, users.user_name AS user_name, hosts.host_name AS host_name
                        FROM build_ports_queue, builds, users, hosts
                       WHERE build_ports_queue.host_id=?
                         AND build_ports_queue.build_id=?
                         AND builds.build_id = build_ports_queue.build_id
                         AND users.user_id = build_ports_queue.user_id
                         AND hosts.host_id = build_ports_queue.host_id
                    ORDER BY priority ASC, build_ports_queue_id ASC";
            $rc = $this->_doQueryHashRef($query, $results, array($host_id,$build_id));

            if (!$rc) {
                return null;
            }

            $build_ports_queue_entries = $this->_newFromArray("BuildPortsQueue", $results);

            return $build_ports_queue_entries;
        }

        function deleteBuildPortsQueueEntry($entry_id) {
            $query = "DELETE FROM build_ports_queue
                            WHERE build_ports_queue_id=?";

            $rc = $this->_doQuery($query, $entry_id, $res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function deleteBuildPortsQueueByUserId($user) {
            $query = "DELETE FROM build_ports_queue
                            WHERE user_id=?";

            $rc = $this->_doQuery($query, $user->getId(), $res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function createBuildPortsQueueEntry($host_id,$build_id,$priority,$port_directory,$user_id,$email_on_completion) {
            switch( $email_on_completion ) {
                case '1':    $email_on_completion = 1; break;
                default:     $email_on_completion = 0; break;
            }

            $entries[] = array('host_id'        => $host_id,
                               'build_id'       => $build_id,
                               'priority'       => $priority,
                               'port_directory' => $port_directory,
                               'user_id'        => $user_id,
                               'enqueue_date'   => date("Y-m-d H:i:s", time()),
                               'email_on_completion' => $email_on_completion,
                               'status'         => 'ENQUEUED');

            $results = $this->_newFromArray("BuildPortsQueue",$entries);

            return $results[0];
        }

        function updateBuildPortsQueueEntry($entry) {

            $query = "UPDATE build_ports_queue
                         SET host_id=?, build_id=?, priority=?, email_on_completion=?, status=?
                       WHERE build_ports_queue_id=?";

            $rc = $this->_doQuery($query, array($entry->getHostId(),$entry->getBuildId(),$entry->getPriority(),$entry->getEmailOnCompletion(),$entry->getStatus(),$entry->getId()), $res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function addBuildPortsQueueEntry($entry) {
            $query = "INSERT INTO build_ports_queue
                         (host_id,enqueue_date,build_id,priority,port_directory,user_id,email_on_completion,status)
                      VALUES
                         (?,?,?,?,?,?,?,?)";

            $rc = $this->_doQuery($query, array($entry->getHostId(),$entry->getEnqueueDate(),$entry->getBuildId(),$entry->getPriority(),$entry->getPortDirectory(),$entry->getUserId(),$entry->getEmailOnCompletion(),$entry->getStatus()), $res);

            if (!$rc) {
                return false;
            }

            return true;
        }

        function getPortsForBuild($build) {
            $query = 'SELECT p.*,
                             bp.last_built,
                             bp.last_status,
                             bp.last_successful_built,
                             bp.last_built_version,
                             bp.last_fail_reason
                        FROM ports p,
                             build_ports bp
                       WHERE p.port_id = bp.port_id
                         AND bp.build_id=?
                    ORDER BY p.port_directory';

            $rc = $this->_doQueryHashRef($query, $results, $build->getId());

            if (!$rc) {
                return null;
            }

            $ports = $this->_newFromArray("Port", $results);

            return $ports;
        }

        function getLatestPorts($build_id,$limit="") {
            $query = 'SELECT p.*,
                             bp.build_id,
                             bp.last_built,
                             bp.last_status,
                             bp.last_successful_built,
                             bp.Last_built_version,
                             bp.last_fail_reason
                        FROM ports p,
                             build_ports bp
                       WHERE p.port_id = bp.port_id
                         AND bp.last_built IS NOT NULL ';
            if($build_id)
                 $query .= "AND bp.build_id=$build_id ";
            $query .= " ORDER BY bp.last_built DESC ";
            if($limit)
                 $query .= " LIMIT $limit";

            $rc = $this->_doQueryHashRef($query, $results, array());

            if (!$rc) {
                return null;
            }

            $ports = $this->_newFromArray("Port", $results);

            return $ports;
        }

        function getPortsByStatus($build_id,$maintainer,$status) {
            $query = 'SELECT p.*,
                             bp.build_id,
                             bp.last_built,
                             bp.last_status,
                             bp.last_successful_built,
                             bp.Last_built_version,
                             bp.last_fail_reason
                        FROM ports p,
                             build_ports bp
                       WHERE p.port_id = bp.port_id ';

            if($build_id)
                 $query .= "AND bp.build_id=$build_id ";
            if($status)
                 $query .= "AND bp.last_status='$status' ";
            if($maintainer)
                 $query .= "AND p.port_maintainer='$maintainer'";
            $query .= " ORDER BY bp.last_built DESC ";

            $rc = $this->_doQueryHashRef($query, $results, array());

            if (!$rc) {
                return null;
            }

            $ports = $this->_newFromArray("Port", $results);

            return $ports;
        }


        function getBuildStats($build_id) {
            $query = 'SELECT COUNT(*) AS fails FROM build_ports WHERE last_status = \'FAIL\' AND build_id = ?';
            $rc = $this->_doQueryHashRef($query, $results, $build_id);
            if (!$rc) return null;
            return $results[0];
        }

        function getPortById($id) {
            $results = $this->getPorts(array( 'port_id' => $id ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getObjects($type, $params = array()) {
            global $objectMap;

            if (!isset($objectMap[$type])) {
                die("Unknown object type, $type\n");
            }

            $table = $objectMap[$type];
            $condition = "";

            $values = array();
            $conds = array();
            foreach ($params as $field => $param) {
                # Each parameter makes up and OR portion of a query.  Within
                # each parameter can be a hash reference that make up the AND
                # portion of the query.
                if (is_array($param)) {
                    $ands = array();
                    foreach ($param as $andcond => $value) {
                        array_push($ands, "$andcond=?");
                        array_push($values, $value);
                    }
                    array_push($conds, "(" . (implode(" AND ", $ands)) . ")");
                } else {
                    array_push($conds, "(" . $field . "=?)");
                    array_push($values, $param);
                }
            }

            $condition = implode(" OR ", $conds);

            if ($condition != "") {
                $query = "SELECT * FROM $table WHERE $condition";
            }
            else {
                $query = "SELECT * FROM $table";
            }

            $results = array();
            $rc = $this->_doQueryHashRef($query, $results, $values);

            if (!$rc) {
                return null;
            }

            return $this->_newFromArray($type, $results);
        }

        function getBuildByName($name) {
            $results = $this->getBuilds(array( 'build_name' => $name ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getBuildById($id) {
            $results = $this->getBuilds(array( 'build_id' => $id ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getBuildPortsQueueEntryById($id) {
            $results = $this->getBuildPortsQueue(array( 'build_ports_queue_id' => $id ));

            if (is_null($results)) {
                 return null;
            }

            return $results[0];
        }

        function getHostById($id) {
            $results = $this->getHosts(array( 'host_id' => $id ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getJailById($id) {
            $results = $this->getJails(array( 'jail_id' => $id ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getPortsTreeForBuild($build) {
            $portstree = $this->getPortsTreeById($build->getPortsTreeId());

            return $portstree;
        }

        function getPortsTreeByName($name) {
             $results = $this->getPortsTrees(array( 'ports_tree_name' => $name ));
             if (is_null($results)) {
                 return null;
             }

             return $results[0];
        }

        function getPortsTreeById($id) {
            $results = $this->getPortsTrees(array( 'ports_tree_id' => $id ));

            if (is_null($results)) {
                 return null;
            }

            return $results[0];
        }

        function getUserById($id) {
            $results = $this->getUsers(array( 'user_id' => $id ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getUserByName($name) {
            $results = $this->getUsers(array( 'user_name' => $name ));

            if (is_null($results)) {
                return null;
            }

            return $results[0];
        }

        function getPortFailReasons($params = array()) {
            return $this->getObjects("PortFailReason", $params);
        }

        function getBuilds($params = array()) {
            return $this->getObjects("Build", $params);
        }

        function getBuildPortsQueue($params = array()) {
            return $this->getObjects("BuildPortsQueue", $params);
        }

        function getHosts($params = array()) {
            return $this->getObjects("Host", $params);
        }

        function getJails($params = array()) {
            return $this->getObjects("Jail", $params);
        }

        function getPortsTrees($params = array()) {
            return $this->getObjects("PortsTree", $params);
        }

        function getUsers($params = array()) {
            return $this->getObjects("User", $params);
        }

        function getAllPortFailReasons() {
            $results = $this->getPortFailReasons();

            return $results;
        }

        function getAllBuilds() {
            $builds = $this->getBuilds();

            return $builds;
        }

        function getAllHosts() {
            $query = "SELECT * FROM hosts WHERE host_name NOT IN ('__ALL__')";

            $rc = $this->_doQueryHashRef($query, $results, array());

            if (!$rc) {
                return null;
            }

            $ports = $this->_newFromArray("Host", $results);

            return $ports;
        }

        function getAllJails() {
            $jails = $this->getJails();

            return $jails;
        }

        function getAllUsers() {
            $users = $this->getUsers();

            return $users;
        }

        function addError($error) {
             return $this->error[] = $error;
        }

        function getErrors() {
             return $this->error;
        }

        function _doQueryNumRows($query, $params = array()) {
            $rows = 0;
            $rc = $this->_doQuery($query, $params, $res);

            if (!$rc) {
                return -1;
            }

            if ($res->numRows() > -1) {
                $rows = $res->numRows();
            }
            else {
                while($res->fetchRow()) {
                    $rows++;
                }
            }

            $res->free();

            return $rows;
        }

        function _doQueryHashRef($query, &$results, $params = array()) {
            $rc = $this->_doQuery($query, $params, $res);

            if (!$rc) {
                $results = null;
                return 0;
            }

            $results = array();
            while ($row = $res->fetchRow()) {
                array_push($results, $row);
            }

            $res->free();

            return 1;
        }

        function _doQuery($query, $params, &$res) {
            $sth = $this->db->prepare($query);

            if (DB::isError($this->db)) {
                $this->addError($this->db->getMessage());
                return 0;
            }

            if (count($params)) {
                $_res = $this->db->execute($sth, $params);
            }
            else {
                $_res = $this->db->execute($sth);
            }

            if (DB::isError($_res)) {
                $this->addError($_res->getMessage());
                return 0;
            }

            if (!is_null($_res)) {
                $res = $_res;
            }
            else {
                $res->free();
            }

            return 1;
        }

        function _newFromArray($type, $arr) {
            $objects = array();

            foreach ($arr as $item) {
                eval('$obj = new $type($item);');
                if (!is_a($obj, $type)) {
                    return null;
                }
                array_push($objects, $obj);
            }

            return $objects;
        }

        function destroy() {
            $this->db->disconnect();
            $this->error = null;
        }

        function cryptPassword($password) {
            return md5($password);
        }

        function getPackageSuffix($jail_id) {
            if (empty($jail_id)) return "";
            /* Use caching to avoid a lot of SQL queries */
            if ( isset($this->packageSuffixCache[$jail_id])) {
                return $this->packageSuffixCache[$jail_id];
            } else {
                $jail = $this->getJailById($jail_id);
                if (substr($jail->getName(), 0, 1) <= "4") {
                        $this->packageSuffixCache[$jail_id] = ".tgz";
                        return ".tgz";
                } else {
                        $this->packageSuffixCache[$jail_id] = ".tbz";
                        return ".tbz";
                }

            }
        }

        /* formatting functions */

         function prettyDatetime($input) {
            if (ereg("[0-9]{14}", $input)) {
                /* timestamp */
                return substr($input,0,4)."-".substr($input,4,2)."-".substr($input,6,2)." ".substr($input,8,2).":".substr($input,10,2).":".substr($input,12,2);
            } elseif (ereg("[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}", $input)) {
                /* datetime */
                if ($input == "0000-00-00 00:00:00") {
                    return "";
                } else {
                    return $input;
                }
            } else {
                return $input;
            }
        }

        function prettyEmail($input) {
            return eregi_replace("@FreeBSD.org", "", $input);
        }

   }
?>
