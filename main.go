package main

import (
	"log"
	"net/http"
	"os"

	"github.com/jinzhu/gorm"
	_ "github.com/jinzhu/gorm/dialects/mysql"
	"github.com/labstack/echo"
	"github.com/labstack/echo/middleware"
)

type User struct {
	Name  string
	Email string
}

func main() {
	e := echo.New()

	e.GET("/", hello)
	e.GET("/users", listUsers)

	e.Use(middleware.Logger())
	e.Logger.Fatal(e.Start(":" + os.Getenv("PORT")))
}

func hello(c echo.Context) error {
	return c.JSON(http.StatusOK, "Hello, World!")
}

func listUsers(c echo.Context) error {
	//MEMO: サンプルコードなので適当に...
	db, err := gorm.Open("mysql", os.Getenv("DB_USER")+":"+os.Getenv("DB_PASSWORD")+"@tcp("+os.Getenv("DB_HOST")+":"+os.Getenv("DB_PORT")+")/"+os.Getenv("DB_DATABASE")+"?charset=utf8&parseTime=True&loc=Local")

	if err != nil {
		log.Println(err)
		return err
	}

	var users []User
	db.Find(&users)

	return c.JSON(http.StatusOK, users)
}
