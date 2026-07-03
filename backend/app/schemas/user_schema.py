"""Marshmallow schemas for request/response validation."""

from marshmallow import Schema, fields, validate


class RegisterSchema(Schema):
  full_name = fields.Str(required=True, validate=validate.Length(min=2, max=120))
  email = fields.Email(required=True)
  password = fields.Str(required=True, validate=validate.Length(min=8, max=128))
  mobile_number = fields.Str(required=False, allow_none=True)


class LoginSchema(Schema):
  email = fields.Email(required=True)
  password = fields.Str(required=True)


class RefreshSchema(Schema):
  refresh_token = fields.Str(required=True)


class ForgotPasswordSchema(Schema):
  email = fields.Email(required=True)


class ResetPasswordSchema(Schema):
  token = fields.Str(required=True, validate=validate.Length(min=16, max=128))
  password = fields.Str(required=True, validate=validate.Length(min=8, max=128))
