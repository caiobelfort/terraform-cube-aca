variable "num_workers" {
  type        = number
  default     = 2
  description = "How many workers the deployment will have"
}

variable "worker_size" {
  type        = string
  description = "The size of individual cubestore worker. 'small' is a 2vCPU 4GiB, 'medium' is a 4vCPU 8GiB and 'large' is a 8vCPU 16GiB"
  default     = "medium"

  validation {
    condition     = contains(["small", "medium", "large"], var.worker_size)
    error_message = "The worker_size must be one of: 'small', 'medium' or 'large'"
  }
}

variable "cube_api_scale" {
  type = object({
    min_size = number
    max_size = number
  })
  description = "The minimum and maximum number of Cube API instances"
  default = {
    min_size = 0
    max_size = 2
  }
}

variable env_prefix {
  type = string
  default = "cube"
}

variable "subscription_id" {
  type = string
}


variable "location" {
  type = string
}

variable "cube_image" {
  type = string
}

variable "cubestore_image" {
  type = string
}

variable allowed_ips {
  type = list(object({
    name = string
    value = string
  }))
}


variable "cube_environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "List of environment variables to set for the deployment"
  default     = []
  sensitive = true
}

variable "acr_name" {
  type = string
  description = "The Azure Container Registry name to pull images"
}

variable "acr_resource_group_name" {
  type = string
}


variable "cube_files_dir" {
  type = string
}

variable "dev_mode" {
  type = bool
  default = false
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  type    = list(string)
  default = ["10.0.0.0/21"]
}

variable "cubestore_log_level" {
  type = string
  default = "info"
}


