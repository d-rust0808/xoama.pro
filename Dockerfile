# Dùng image Nginx Alpine vì nó cực kỳ nhẹ (chỉ khoảng mười mấy MB)
FROM nginx:alpine

# Xóa trang html mặc định của nginx
RUN rm -rf /usr/share/nginx/html/*

# Copy file index.html và ảnh vào container
COPY index.html background.jpg /usr/share/nginx/html/

# Expose port 80 cho Nginx nghe
EXPOSE 80

# Chạy Nginx
CMD ["nginx", "-g", "daemon off;"]
