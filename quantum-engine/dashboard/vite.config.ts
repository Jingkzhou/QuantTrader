import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // ▼▼▼ 添加或修改这一部分 ▼▼▼
  server: {
    host: '0.0.0.0', // 允许局域网/Docker 访问（如果还没加的话）
    port: 5173,      // 确保端口对上

    // 允许的域名列表
    allowedHosts: [
      'mondayquest.top',
      'www.mondayquest.top'
    ]
  }
  // ▲▲▲ 修改结束 ▲▲▲
})
