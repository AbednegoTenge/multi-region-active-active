variable "name" {
  description = "Table name. Global Tables keep the same name in every region."
  type        = string
}

variable "hash_key" {
  description = "Partition key attribute name (stored as a string)."
  type        = string
}

variable "range_key" {
  description = "Sort key attribute name (stored as a string)."
  type        = string
}

variable "replica_regions" {
  description = "Extra regions to replicate to. Empty = single-region table. Must not include the provider's own region."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.replica_regions) == length(distinct(var.replica_regions))
    error_message = "replica_regions must not contain duplicates."
  }
}

variable "tags" {
  description = "Tags applied to the table."
  type        = map(string)
  default     = {}
}
