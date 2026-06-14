package com.waste.utils;

import com.waste.common.LoginUser;

public class UserContext {

    private static final ThreadLocal<LoginUser> USER_HOLDER = new ThreadLocal<>();

    private UserContext() {
    }

    public static void setCurrentUser(LoginUser loginUser) {
        USER_HOLDER.set(loginUser);
    }

    public static LoginUser getCurrentUser() {
        return USER_HOLDER.get();
    }

    public static Long getCurrentUserId() {
        LoginUser loginUser = USER_HOLDER.get();
        return loginUser != null ? loginUser.getUserId() : null;
    }

    public static String getCurrentUsername() {
        LoginUser loginUser = USER_HOLDER.get();
        return loginUser != null ? loginUser.getUsername() : null;
    }

    public static String getCurrentRealName() {
        LoginUser loginUser = USER_HOLDER.get();
        return loginUser != null ? loginUser.getRealName() : null;
    }

    public static String getCurrentRole() {
        LoginUser loginUser = USER_HOLDER.get();
        return loginUser != null ? loginUser.getRole() : null;
    }

    public static Long getCurrentEnterpriseId() {
        LoginUser loginUser = USER_HOLDER.get();
        return loginUser != null ? loginUser.getEnterpriseId() : null;
    }

    public static String getCurrentToken() {
        LoginUser loginUser = USER_HOLDER.get();
        return loginUser != null ? loginUser.getToken() : null;
    }

    public static void clear() {
        USER_HOLDER.remove();
    }
}
