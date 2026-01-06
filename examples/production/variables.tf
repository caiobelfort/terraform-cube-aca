variable "subscription_id" {
  type = string
}

variable "acr_name" {
  type = string
}

variable "acr_resource_group_name" {
  type = string
}

variable "cube_image" {
  type = string
}
variable "cubestore_image" {
  type = string
}

variable "allowed_ips" {
  type = list(object({
    name = string
    value = string
  }))
}

variable "cube_envs" {
  type = list(object({
    name = string
    value = string
  }))
  sensitive = true
}
