import React, { useState, useEffect, useCallback } from 'react';
import { Send, ArrowDownLeft, Clock, CheckCircle, XCircle, Activity, Bell, Wallet, AlertCircle, LogOut, User } from 'lucide-react';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3000/api';

class APIClient {
  static getToken() {
    return localStorage.getItem('accessToken');
  }

  static setToken(token) {
    localStorage.setItem('accessToken', token);
  }

  static removeToken() {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('user');
  }

  static async request(endpoint, options = {}) {
    const token = this.getToken();
    
    try {
      const response = await fetch(`${API_BASE_URL}${endpoint}`, {
        headers: {
          'Content-Type': 'application/json',
          ...(token && { 'Authorization': `Bearer ${token}` }),
          ...options.headers,
        },
        ...options,
      });

      if (response.status === 401) {
        this.removeToken();
        window.location.href = '/';
        throw new Error('Session expired');
      }

      if (!response.ok) {
        const error = await response.json().catch(() => ({ error: 'Request failed' }));
        throw new Error(error.error || `HTTP ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      throw error;
    }
  }

  static async login(email, password) {
    const data = await this.request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    this.setToken(data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    localStorage.setItem('user', JSON.stringify(data.user));
    return data;
  }

  static async register(email, password, name) {
    const data = await this.request('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, password, name }),
    });
    this.setToken(data.accessToken);
    localStorage.setItem('refreshToken', data.refreshToken);
    localStorage.setItem('userId', data.userId);
    return data;
  }

  static async logout() {
    try {
      await this.request('/auth/logout', { method: 'POST' });
    } finally {
      this.removeToken();
    }
  }

  static async getWallets() {
    return this.request('/wallets');
  }

  static async getWallet(userId) {
    return this.request(`/wallets/${userId}`);
  }

  static async createTransaction(data) {
    return this.request('/transactions', {
      method: 'POST',
      body: JSON.stringify({
        fromUserId: data.from,
        toUserId: data.to,
        amount: parseFloat(data.amount)
      }),
    });
  }

  static async getTransactions(userId = null) {
    const query = userId ? `?userId=${userId}` : '';
    return this.request(`/transactions${query}`);
  }

  static async getNotifications(userId) {
    return this.request(`/notifications/${userId}`);
  }

  static async getMetrics() {
    return this.request('/metrics');
  }
}

function LoginPage({ onLogin }) {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async () => {
    setLoading(true);
    setError(null);

    try {
      if (isLogin) {
        const data = await APIClient.login(email, password);
        onLogin(data.user);
      } else {
        const data = await APIClient.register(email, password, name);
        onLogin({ id: data.userId, email, name });
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-blue-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 w-full max-w-md">
        <div className="flex items-center justify-center mb-8">
          <div className="w-16 h-16 bg-gradient-to-br from-blue-600 to-blue-700 rounded-2xl flex items-center justify-center">
            <Wallet className="w-10 h-10 text-white" />
          </div>
        </div>

        <h1 className="text-3xl font-bold text-center text-slate-900 mb-2">PayFlow</h1>
        <p className="text-center text-slate-600 mb-8">Secure Digital Wallet</p>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-start space-x-3">
            <AlertCircle className="w-5 h-5 text-red-600 mt-0.5" />
            <p className="text-sm text-red-800">{error}</p>
          </div>
        )}

        <div className="space-y-4">
          {!isLogin && (
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-2">Full Name</label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-4 py-3 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="John Doe"
              />
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-3 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="you@example.com"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-slate-700 mb-2">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-3 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="••••••••"
            />
            {!isLogin && (
              <p className="text-xs text-slate-500 mt-1">
                At least 8 characters with uppercase, lowercase, and number
              </p>
            )}
          </div>

          <button
            onClick={handleSubmit}
            disabled={loading || !email || !password || (!isLogin && !name)}
            className="w-full bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:bg-slate-300 disabled:cursor-not-allowed flex items-center justify-center space-x-2"
          >
            {loading ? (
              <>
                <Activity className="w-5 h-5 animate-spin" />
                <span>Processing...</span>
              </>
            ) : (
              <span>{isLogin ? 'Sign In' : 'Create Account'}</span>
            )}
          </button>
        </div>

        <div className="mt-6 text-center">
          <button
            onClick={() => {
              setIsLogin(!isLogin);
              setError(null);
            }}
            className="text-sm text-blue-600 hover:text-blue-700"
          >
            {isLogin ? "Don't have an account? Sign up" : 'Already have an account? Sign in'}
          </button>
        </div>

        <div className="mt-8 p-4 bg-blue-50 rounded-lg">
          <p className="text-xs text-blue-800 text-center">
            🔒 Secured with JWT authentication, encrypted connections, and industry-standard security
          </p>
        </div>
      </div>
    </div>
  );
}

export default function PayFlowApp() {
  const [user, setUser] = useState(null);
  const [wallet, setWallet] = useState(null);
  const [allWallets, setAllWallets] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [metrics, setMetrics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  
  const [sendAmount, setSendAmount] = useState('');
  const [recipient, setRecipient] = useState('');
  const [sendLoading, setSendLoading] = useState(false);
  const [sendSuccess, setSendSuccess] = useState(false);

  useEffect(() => {
    const storedUser = localStorage.getItem('user');
    if (storedUser) {
      setUser(JSON.parse(storedUser));
    }
    setLoading(false);
  }, []);

  const fetchWallet = useCallback(async () => {
    if (!user) return;
    try {
      const data = await APIClient.getWallet(user.id);
      setWallet(data);
      setError(null);
    } catch (err) {
      setError(`Failed to load wallet: ${err.message}`);
    }
  }, [user]);

  const fetchAllWallets = useCallback(async () => {
    try {
      const data = await APIClient.getWallets();
      setAllWallets(data);
    } catch (err) {
      console.error('Failed to load wallets:', err);
    }
  }, []);

  const fetchTransactions = useCallback(async () => {
    if (!user) return;
    try {
      const data = await APIClient.getTransactions(user.id);
      setTransactions(data);
    } catch (err) {
      console.error('Failed to load transactions:', err);
    }
  }, [user]);

  const fetchNotifications = useCallback(async () => {
    if (!user) return;
    try {
      const data = await APIClient.getNotifications(user.id);
      setNotifications(data);
    } catch (err) {
      console.error('Failed to load notifications:', err);
    }
  }, [user]);

  const fetchMetrics = useCallback(async () => {
    try {
      const data = await APIClient.getMetrics();
      setMetrics(data);
    } catch (err) {
      console.error('Failed to load metrics:', err);
    }
  }, []);

  useEffect(() => {
    if (user) {
      const loadData = async () => {
        await Promise.all([
          fetchWallet(),
          fetchAllWallets(),
          fetchTransactions(),
          fetchNotifications(),
          fetchMetrics()
        ]);
      };
      loadData();
    }
  }, [user, fetchWallet, fetchAllWallets, fetchTransactions, fetchNotifications, fetchMetrics]);

  useEffect(() => {
    if (!user) return;
    const interval = setInterval(() => {
      fetchWallet();
      fetchTransactions();
      fetchNotifications();
      fetchMetrics();
    }, 3000);

    return () => clearInterval(interval);
  }, [user, fetchWallet, fetchTransactions, fetchNotifications, fetchMetrics]);

  const handleSendMoney = async () => {
    const amount = parseFloat(sendAmount);
    
    if (!amount || amount <= 0 || !recipient) {
      setError('Please enter a valid amount and select a recipient');
      return;
    }

    if (wallet && amount > parseFloat(wallet.balance)) {
      setError('Insufficient funds');
      return;
    }

    setSendLoading(true);
    setSendSuccess(false);
    setError(null);

    try {
      await APIClient.createTransaction({
        from: user.id,
        to: recipient,
        amount: amount
      });

      setSendAmount('');
      setRecipient('');
      setSendSuccess(true);
      
      setTimeout(() => {
        fetchWallet();
        fetchTransactions();
      }, 500);

      setTimeout(() => setSendSuccess(false), 3000);
    } catch (err) {
      setError(`Transaction failed: ${err.message}`);
    } finally {
      setSendLoading(false);
    }
  };

  const handleLogout = async () => {
    await APIClient.logout();
    setUser(null);
    setWallet(null);
    setTransactions([]);
    setNotifications([]);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center">
        <Activity className="w-12 h-12 text-blue-600 animate-spin" />
      </div>
    );
  }

  if (!user) {
    return <LoginPage onLogin={setUser} />;
  }

  const otherUsers = allWallets.filter(u => u.user_id !== user.id);
  const queueMetrics = {
    queued: transactions.filter(t => t.status === 'PENDING').length,
    processing: transactions.filter(t => t.status === 'PROCESSING').length,
    completed: transactions.filter(t => t.status === 'COMPLETED').length,
    failed: transactions.filter(t => t.status === 'FAILED').length
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100">
      <header className="bg-white border-b border-slate-200 shadow-sm">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-gradient-to-br from-blue-600 to-blue-700 rounded-lg flex items-center justify-center">
                <Wallet className="w-6 h-6 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-slate-900">PayFlow</h1>
                <p className="text-xs text-slate-500">Production Platform</p>
              </div>
            </div>
            
            <div className="flex items-center space-x-4">
              {metrics && (
                <div className="flex items-center space-x-2 text-sm">
                  <div className={`w-2 h-2 rounded-full ${
                    metrics.gateway?.status === 'healthy' ? 'bg-green-500 animate-pulse' : 'bg-red-500'
                  }`}></div>
                  <span className="text-slate-600 hidden sm:inline">System Status</span>
                </div>
              )}
              <div className="flex items-center space-x-2 px-3 py-2 bg-slate-100 rounded-lg">
                <User className="w-4 h-4 text-slate-600" />
                <span className="text-sm font-medium text-slate-900">{user.name}</span>
              </div>
              <button
                onClick={handleLogout}
                className="flex items-center space-x-2 px-3 py-2 text-slate-600 hover:text-slate-900 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <LogOut className="w-4 h-4" />
                <span className="text-sm hidden sm:inline">Logout</span>
              </button>
            </div>
          </div>
        </div>
      </header>

      <nav className="bg-white border-b border-slate-200">
        <div className="max-w-7xl mx-auto px-6">
          <div className="flex space-x-8">
            {['dashboard', 'send', 'activity', 'monitoring'].map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-4 py-3 text-sm font-medium border-b-2 transition-colors ${
                  activeTab === tab
                    ? 'border-blue-600 text-blue-600'
                    : 'border-transparent text-slate-600 hover:text-slate-900'
                }`}
              >
                {tab.charAt(0).toUpperCase() + tab.slice(1)}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {error && (
        <div className="max-w-7xl mx-auto px-6 pt-4">
          <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-start space-x-3">
            <AlertCircle className="w-5 h-5 text-red-600 mt-0.5" />
            <div className="flex-1">
              <p className="text-sm text-red-800">{error}</p>
              <button onClick={() => setError(null)} className="text-xs text-red-600 hover:text-red-700 mt-1 underline">
                Dismiss
              </button>
            </div>
          </div>
        </div>
      )}

      {sendSuccess && (
        <div className="max-w-7xl mx-auto px-6 pt-4">
          <div className="bg-green-50 border border-green-200 rounded-lg p-4 flex items-start space-x-3">
            <CheckCircle className="w-5 h-5 text-green-600 mt-0.5" />
            <p className="text-sm text-green-800">Transaction submitted! Processing asynchronously via RabbitMQ...</p>
          </div>
        </div>
      )}

      <main className="max-w-7xl mx-auto px-6 py-8">
        {activeTab === 'dashboard' && wallet && (
          <div className="space-y-6">
            <div className="bg-gradient-to-br from-blue-600 to-blue-700 rounded-2xl p-8 text-white shadow-lg">
              <div className="flex justify-between items-start">
                <div>
                  <p className="text-blue-100 text-sm mb-2">Available Balance</p>
                  <h2 className="text-4xl font-bold">${parseFloat(wallet.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}</h2>
                  <p className="text-blue-100 text-sm mt-4">{wallet.name}</p>
                  <p className="text-blue-200 text-xs mt-1">{wallet.user_id}</p>
                </div>
                <Wallet className="w-12 h-12 text-blue-300 opacity-50" />
              </div>
            </div>

            <div className="grid grid-cols-4 gap-4">
              <div className="bg-white rounded-xl p-6 shadow-sm border border-slate-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-slate-600 text-sm">Pending</span>
                  <Clock className="w-4 h-4 text-amber-500" />
                </div>
                <p className="text-2xl font-bold text-slate-900">{queueMetrics.queued}</p>
              </div>
              <div className="bg-white rounded-xl p-6 shadow-sm border border-slate-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-slate-600 text-sm">Processing</span>
                  <Activity className="w-4 h-4 text-blue-500" />
                </div>
                <p className="text-2xl font-bold text-slate-900">{queueMetrics.processing}</p>
              </div>
              <div className="bg-white rounded-xl p-6 shadow-sm border border-slate-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-slate-600 text-sm">Completed</span>
                  <CheckCircle className="w-4 h-4 text-green-500" />
                </div>
                <p className="text-2xl font-bold text-slate-900">{queueMetrics.completed}</p>
              </div>
              <div className="bg-white rounded-xl p-6 shadow-sm border border-slate-200">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-slate-600 text-sm">Failed</span>
                  <XCircle className="w-4 h-4 text-red-500" />
                </div>
                <p className="text-2xl font-bold text-slate-900">{queueMetrics.failed}</p>
              </div>
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
              <div className="flex items-center space-x-2 mb-4">
                <Bell className="w-5 h-5 text-slate-600" />
                <h3 className="font-semibold text-slate-900">Recent Notifications</h3>
              </div>
              <div className="space-y-3">
                {notifications.slice(0, 5).map(notif => (
                  <div key={notif.id} className="flex items-start space-x-3 p-3 bg-slate-50 rounded-lg">
                    <div className={`w-2 h-2 rounded-full mt-2 ${
                      notif.type === 'TRANSACTION_COMPLETED' ? 'bg-green-500' :
                      notif.type === 'TRANSACTION_RECEIVED' ? 'bg-blue-500' : 'bg-red-500'
                    }`} />
                    <div className="flex-1">
                      <p className="text-sm text-slate-900">{notif.message}</p>
                      <p className="text-xs text-slate-500 mt-1">{new Date(notif.created_at).toLocaleString()}</p>
                    </div>
                  </div>
                ))}
                {notifications.length === 0 && (
                  <p className="text-sm text-slate-500 text-center py-4">No notifications yet</p>
                )}
              </div>
            </div>
          </div>
        )}

        {activeTab === 'send' && wallet && (
          <div className="max-w-2xl mx-auto">
            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-8">
              <div className="flex items-center space-x-3 mb-6">
                <Send className="w-6 h-6 text-blue-600" />
                <h2 className="text-2xl font-bold text-slate-900">Send Money</h2>
              </div>
              
              <div className="space-y-6">
                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Recipient</label>
                  <select
                    value={recipient}
                    onChange={(e) => setRecipient(e.target.value)}
                    disabled={sendLoading}
                    className="w-full px-4 py-3 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Select recipient</option>
                    {otherUsers.map(u => (
                      <option key={u.user_id} value={u.user_id}>{u.name} ({u.user_id})</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-slate-700 mb-2">Amount</label>
                  <div className="relative">
                    <span className="absolute left-4 top-3 text-slate-500 text-lg">$</span>
                    <input
                      type="number"
                      value={sendAmount}
                      onChange={(e) => setSendAmount(e.target.value)}
                      disabled={sendLoading}
                      placeholder="0.00"
                      step="0.01"
                      className="w-full pl-8 pr-4 py-3 border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <p className="text-sm text-slate-500 mt-2">
                    Available: ${parseFloat(wallet.balance).toLocaleString('en-US', { minimumFractionDigits: 2 })}
                  </p>
                </div>

                <button
                  onClick={handleSendMoney}
                  disabled={sendLoading || !sendAmount || !recipient}
                  className="w-full bg-blue-600 text-white py-3 rounded-lg font-medium hover:bg-blue-700 transition-colors disabled:bg-slate-300 flex items-center justify-center space-x-2"
                >
                  {sendLoading ? (
                    <>
                      <Activity className="w-5 h-5 animate-spin" />
                      <span>Processing...</span>
                    </>
                  ) : (
                    <>
                      <Send className="w-5 h-5" />
                      <span>Send Money</span>
                    </>
                  )}
                </button>
              </div>

              <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <p className="text-sm text-blue-800">
                  <strong>Secure:</strong> Transactions are processed asynchronously through RabbitMQ with full audit logging.
                </p>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'activity' && (
          <div className="bg-white rounded-xl shadow-sm border border-slate-200">
            <div className="p-6 border-b border-slate-200">
              <h2 className="text-xl font-bold text-slate-900">Transaction History</h2>
            </div>
            <div className="p-6">
              <div className="space-y-3">
                {transactions.map(txn => {
                  const isOutgoing = txn.from_user_id === user.id;
                  const otherParty = isOutgoing ? txn.to_user_id : txn.from_user_id;
                  const otherWallet = allWallets.find(w => w.user_id === otherParty);
                  
                  return (
                    <div key={txn.id} className="flex items-center justify-between p-4 bg-slate-50 rounded-lg hover:bg-slate-100 transition-colors">
                      <div className="flex items-center space-x-4">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                          isOutgoing ? 'bg-red-100' : 'bg-green-100'
                        }`}>
                          {isOutgoing ? <Send className="w-5 h-5 text-red-600" /> : <ArrowDownLeft className="w-5 h-5 text-green-600" />}
                        </div>
                        <div>
                          <p className="font-medium text-slate-900">
                            {isOutgoing ? 'Sent to' : 'Received from'} {otherWallet?.name || otherParty}
                          </p>
                          <p className="text-sm text-slate-500 font-mono">{txn.id}</p>
                          <p className="text-xs text-slate-400 mt-1">{new Date(txn.created_at).toLocaleString()}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className={`font-bold text-lg ${isOutgoing ? 'text-red-600' : 'text-green-600'}`}>
                          {isOutgoing ? '-' : '+'}${parseFloat(txn.amount).toFixed(2)}
                        </p>
                        <div className="flex items-center justify-end space-x-1 mt-1">
                          {txn.status === 'PENDING' && (
                            <>
                              <Clock className="w-4 h-4 text-amber-500" />
                              <span className="text-xs text-amber-600 font-medium">Pending</span>
                            </>
                          )}
                          {txn.status === 'PROCESSING' && (
                            <>
                              <Activity className="w-4 h-4 text-blue-500 animate-spin" />
                              <span className="text-xs text-blue-600 font-medium">Processing</span>
                            </>
                          )}
                          {txn.status === 'COMPLETED' && (
                            <>
                              <CheckCircle className="w-4 h-4 text-green-500" />
                              <span className="text-xs text-green-600 font-medium">Completed</span>
                            </>
                          )}
                          {txn.status === 'FAILED' && (
                            <>
                              <XCircle className="w-4 h-4 text-red-500" />
                              <span className="text-xs text-red-600 font-medium">Failed</span>
                            </>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
                {transactions.length === 0 && (
                  <p className="text-center text-slate-500 py-8">No transactions yet</p>
                )}
              </div>
            </div>
          </div>
        )}

        {activeTab === 'monitoring' && metrics && (
          <div className="space-y-6">
            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
              <h2 className="text-xl font-bold text-slate-900 mb-6">Microservices Health</h2>
              
              {Object.entries({
                'API Gateway': metrics.gateway,
                'Wallet Service': metrics.walletService,
                'Transaction Service': metrics.transactionService,
                'Notification Service': metrics.notificationService
              }).map(([name, service]) => (
                <div key={name} className="mb-6 last:mb-0">
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="font-semibold text-slate-900">{name}</h3>
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${
                      service?.status === 'healthy' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                    }`}>
                      {service?.status === 'healthy' ? 'HEALTHY' : 'UNHEALTHY'}
                    </span>
                  </div>
                  {service?.database && (
                    <div className="grid grid-cols-2 gap-4 mt-3">
                      <div className="p-3 bg-blue-50 rounded-lg">
                        <p className="text-xs text-blue-600 mb-1">Database</p>
                        <p className="text-sm font-medium text-blue-900">{service.database}</p>
                      </div>
                      {service.redis && (
                        <div className="p-3 bg-purple-50 rounded-lg">
                          <p className="text-xs text-purple-600 mb-1">Redis Cache</p>
                          <p className="text-sm font-medium text-purple-900">{service.redis}</p>
                        </div>
                      )}
                      {service.rabbitmq && (
                        <div className="p-3 bg-orange-50 rounded-lg">
                          <p className="text-xs text-orange-600 mb-1">RabbitMQ</p>
                          <p className="text-sm font-medium text-orange-900">{service.rabbitmq}</p>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>

            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
              <h3 className="font-semibold text-slate-900 mb-4">Production Architecture</h3>
              <div className="space-y-3 text-sm text-slate-600">
                <div className="flex items-start space-x-2">
                  <div className="w-2 h-2 bg-blue-600 rounded-full mt-1.5" />
                  <p><strong>JWT Auth:</strong> Bearer token authentication with refresh tokens</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-2 h-2 bg-green-600 rounded-full mt-1.5" />
                  <p><strong>PostgreSQL:</strong> ACID transactions with row-level locking</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-2 h-2 bg-purple-600 rounded-full mt-1.5" />
                  <p><strong>Redis:</strong> Session caching and idempotency tracking</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-2 h-2 bg-orange-600 rounded-full mt-1.5" />
                  <p><strong>RabbitMQ:</strong> Async processing with DLQ and retry logic</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-2 h-2 bg-amber-600 rounded-full mt-1.5" />
                  <p><strong>Circuit Breakers:</strong> Resilient service communication</p>
                </div>
                <div className="flex items-start space-x-2">
                  <div className="w-2 h-2 bg-red-600 rounded-full mt-1.5" />
                  <p><strong>Observability:</strong> Prometheus metrics + structured logging</p>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
