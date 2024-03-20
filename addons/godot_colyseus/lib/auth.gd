extends RefCounted

const promises = preload("res://addons/godot_colyseus/lib/promises.gd")
const Promise = promises.Promise;
const RunPromise = promises.RunPromise;
const HTTP = preload("res://addons/godot_colyseus/lib/http.gd")
const HttpUtils = preload("res://addons/godot_colyseus/lib/http_utils.gd")

var token: String
var endpoint: String

func _init(endpoint: String):
	self.endpoint = endpoint

func signup_with_email_and_password(email: String, password: String, options: Dictionary = {}) -> Promise:
	return RunPromise.new(
		_signup_with_email_and_password,
		[email, password, options])

func signin_with_email_and_password(email: String, password: String) -> Promise:
	return RunPromise.new(
		_signin_with_email_and_password,
		[email, password])

func _signup_with_email_and_password(
	promise: Promise,
	email: String,
	password: String,
	options: Dictionary):
	var resp = RunPromise.new(HttpUtils.POST, [self.endpoint, "/auth/register", { "options": options, "email": email, "password": password } ])

	if resp.get_state() == Promise.State.Waiting:
		await resp.completed
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var response = resp.get_data()

	if response.get('error') != null:
		promise.reject(response['error'])
		return

	self.token = response['token']
	promise.resolve(response)

func _signin_with_email_and_password(
	promise: Promise,
	email: String,
	password: String):
	var resp = RunPromise.new(HttpUtils.POST, [self.endpoint, "/auth/login", {"email": email, "password": password } ])

	if resp.get_state() == Promise.State.Waiting:
		await resp.completed
	if resp.get_state() == Promise.State.Failed:
		promise.reject(resp.get_error())
		return
	var response = resp.get_data()

	if response.get('error') != null:
		promise.reject(response['error'])
		return

	self.token = response['token']
	promise.resolve(response)
