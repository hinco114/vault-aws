# 생성된 IAM 사용자 이름을 외부로 전달
output "user_name" {
  description = "생성된 IAM 사용자 이름."
  value       = aws_iam_user.demo_user.name
}

# 생성된 Access Key ID 를 외부로 전달
output "access_key_id" {
  description = "생성된 Access Key ID."
  value       = aws_iam_access_key.demo_user.id
}

# 생성된 Secret Access Key 를 민감정보로 외부에 전달
output "secret_access_key" {
  description = "생성된 Secret Access Key."
  value       = aws_iam_access_key.demo_user.secret
  sensitive   = true
}
