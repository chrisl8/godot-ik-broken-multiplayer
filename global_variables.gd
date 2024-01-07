extends Node

var is_server: bool = false
var force_client: bool = false
var shutdown_server: bool = false
var local_debug_instance_number: int = -1
var url: String
var shutdown_in_progress: bool = false
var connection_failed_message: String = "Connection Failed!"
var my_camera: Camera2D
