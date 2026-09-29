import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './contexts/AuthContext'
import { ProtectedRoute } from './components/ProtectedRoute'
import { Shell } from './components/Shell'
import { ForgotPassword, LoginPage, NotFound, ResetPassword, SignupPage } from './pages/Pages'
import { AskNearbyPage, CustomerActivityPage, CustomerChatPage, CustomerHome, CustomerNotificationsPage, CustomerProductPage, CustomerSearchPage, CustomerShopPage } from './pages/CustomerPages'
import { CustomerProfilePage } from './pages/CustomerProfilePage'
import { AdminDashboard, SellerChat, SellerDashboard, SellerInquiries, SellerProducts, SellerRequests, SellerReservations, SellerShopManagement } from './pages/SellerAdminPages'

export default function App() {
 return <BrowserRouter><AuthProvider><Routes><Route element={<Shell/>}>
  <Route index element={<CustomerHome/>}/><Route path="search" element={<CustomerSearchPage/>}/><Route path="products/:id" element={<CustomerProductPage/>}/><Route path="shops/:id" element={<CustomerShopPage/>}/>
  <Route path="login" element={<LoginPage/>}/><Route path="signup" element={<SignupPage/>}/><Route path="forgot-password" element={<ForgotPassword/>}/><Route path="reset-password" element={<ResetPassword/>}/>
  <Route element={<ProtectedRoute roles={['customer']}/> }>
   <Route path="profile" element={<CustomerProfilePage/>}/><Route path="activity" element={<CustomerActivityPage/>}/><Route path="chat" element={<CustomerChatPage/>}/><Route path="chat/:id" element={<CustomerChatPage/>}/><Route path="reservations" element={<CustomerActivityPage/>}/><Route path="notifications" element={<CustomerNotificationsPage/>}/><Route path="ask-nearby" element={<AskNearbyPage/>}/>
  </Route>
  <Route element={<ProtectedRoute roles={['shopkeeper']}/> }><Route path="seller" element={<SellerDashboard/>}/><Route path="seller/shop" element={<SellerShopManagement/>}/><Route path="seller/products" element={<SellerProducts/>}/><Route path="seller/inquiries" element={<SellerInquiries/>}/><Route path="seller/reservations" element={<SellerReservations/>}/><Route path="seller/requests" element={<SellerRequests/>}/><Route path="seller/chat" element={<SellerChat/>}/><Route path="seller/chat/:id" element={<SellerChat/>}/><Route path="seller/notifications" element={<CustomerNotificationsPage/>}/></Route>
  <Route element={<ProtectedRoute roles={['admin']}/> }><Route path="admin" element={<AdminDashboard/>}/></Route>
  <Route path="*" element={<NotFound/>}/>
 </Route></Routes></AuthProvider></BrowserRouter>
}
